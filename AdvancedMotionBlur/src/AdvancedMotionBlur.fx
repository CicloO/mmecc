#include "Settings.fxh"
#include "Fullscreen.fxh"
#include "ModelTiming.fxh"
#include "Coverage.fxh"

float2 ScreenSize : VIEWPORTPIXELSIZE;

float StreakPixelScale()
{
#if MB_SCALE_STREAK_WITH_HEIGHT
    return ScreenSize.y / 1080.0;
#else
    return 1.0;
#endif
}

#include "Controller.fxh"
#include "HistoryTargets.fxh"

#define MB_USE_FOREGROUND (MB_EXTEND_FOREGROUND && MB_DEBUG == 0)
#define MB_USE_TRAIL_ALPHA (MB_TRAIL_ALPHA && MB_DEBUG == 0)

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

float4x4 ViewProjection : VIEWPROJECTION;
float4x4 InverseViewProjection : VIEWPROJECTIONINVERSE;
float4x4 View : VIEW;
float4x4 Projection : PROJECTION;
float Timeline : TIME < bool SyncInEditMode = true; >;
float AccessoryScale : CONTROLOBJECT < string name = "(self)"; >;

#if MB_USE_TRAIL_ALPHA
static const float4 ClearColor = {MB_CLEAR_RGBA};
float4 SceneClear = float4(ClearColor.rgb * ClearColor.a, ClearColor.a);
#else
float4 SceneClear = {MB_CLEAR_RGBA};
#endif
float DepthClear = 1.0;

texture SceneColor : RENDERCOLORTARGET < string Format = "A8R8G8B8"; >;
texture SceneDepth : RENDERDEPTHSTENCILTARGET;
texture CameraDepth : RENDERDEPTHSTENCILTARGET < int Width = 8; int Height = 1; >;
texture CameraAnalysis : RENDERCOLORTARGET <
    int Width = 1;
    int Height = 1;
    string Format = "A32B32G32R32F";
>;
texture AnalysisDepth : RENDERDEPTHSTENCILTARGET < int Width = 1; int Height = 1; >;

texture GeometryData : OFFSCREENRENDERTARGET <
    string Description = "AdvancedMotionBlur - depth and motion";
    string Format = "A16B16G16R16F";
    float4 ClearColor = {0.0, 0.0, 0.0, 0.0};
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string DefaultEffect =
        "self = hide;"
        MB_CONTROLLER_NAME " = hide;"
#if MB_AUTO_MODEL_MOTION
        "*.pmx = MotionGeometry.fx;"
        "*.pmd = MotionGeometry.fx;"
#endif
#if MB_ACCESSORY_MOTION
        "*.x = RigidMotion.fx;"
#endif
        "* = DepthVelocity.fx;";
>;

#define MB_POINT_FILTER \
    MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; \
    AddressU = CLAMP; AddressV = CLAMP; SRGBTexture = FALSE;
sampler2D SceneSampler = sampler_state { Texture = <SceneColor>; MB_POINT_FILTER };

#ifndef MB_LINEAR_COLOR
#define MB_LINEAR_COLOR 1
#endif
// Trail taps land between pixels. Filtering their colour lets a thin, slanted
// outline fade evenly instead of flipping between line and background.
// Geometry stays point-sampled so depth and coverage tests are not blended.
sampler2D SceneTapSampler = sampler_state {
    Texture = <SceneColor>;
#if MB_LINEAR_COLOR
    MinFilter = LINEAR; MagFilter = LINEAR;
#else
    MinFilter = POINT; MagFilter = POINT;
#endif
    MipFilter = NONE; AddressU = CLAMP; AddressV = CLAMP; SRGBTexture = FALSE;
};
sampler2D CameraSampler = sampler_state { Texture = <AMB_CameraHistory>; MB_POINT_FILTER };
sampler2D AnalysisSampler = sampler_state { Texture = <CameraAnalysis>; MB_POINT_FILTER };
sampler2D GeometrySampler = sampler_state { Texture = <GeometryData>; MB_POINT_FILTER };
#if MB_KEEP_OBJECT_MOTION_ON_CUT
sampler2D CutMotionSampler = sampler_state { Texture = <AMB_CutMotion>; MB_POINT_FILTER };
float4 CutMotionClear = {0.0, 0.0, 0.0, 0.0};
#endif

// Shutter angles refer to a 30 fps frame. Screen velocity is measured per
// second, so the streak length does not depend on the export frame rate.
static const float ShutterReferenceFps = 30.0;

float ExposureScale()
{
    float strength = max(0.0, AccessoryScale * 0.1 * MotionStrength());
    return MotionShutter() * strength / ShutterReferenceFps;
}

#include "Camera.fxh"

float2 ExposureStreak(float2 uv, float4 geometry, float4 camera)
{
    float dt = CameraBlurInterval(camera);
    if (dt <= 0.0 || !HasGeometryCoverage(geometry.a) || geometry.a > 2.5) {
        return 0.0;
    }
    float2 delta;
#if MB_KEEP_OBJECT_MOTION_ON_CUT
    if (camera.w > 0.5) {
        float2 sampleUV = uv + 0.5 / ScreenSize;
        float4 localMotion = tex2Dlod(CutMotionSampler, float4(sampleUV, 0.0, 0.0));
        delta = localMotion.a > 0.5 && abs(localMotion.b - geometry.b) < 0.002 ? localMotion.rg : 0.0;
    } else
#endif
    {
#if MB_TRANSLUCENT_MOTION
        float motionCoverage = abs(geometry.a);
#else
        float motionCoverage = geometry.a;
#endif
        delta = HasModelMotion(motionCoverage, dt) ? geometry.rg : CameraDisplacement(uv, geometry.b);
    }
    float distance = length(delta);
    if (!(distance >= 0.01 && distance < length(ScreenSize) * 0.65)) {
        return 0.0;
    }
    // Dead zone: slow parts lose their whole streak, fast parts lose the same
    // length, so the transition stays continuous (no popping at the edge).
    float extent = max(0.0, distance * camera.y / dt - MotionSpeedThreshold());
    extent = min(MotionStreakLimit(), extent);
    return delta * (extent / distance);
}

float MinStreak()
{
    return 0.75 * StreakPixelScale();
}

float StreakTapBudget(float referenceTaps)
{
    // Leave room for high-resolution taps within the ps_3_0 loop limit.
    return min(255.0, ceil(referenceTaps * max(1.0, StreakPixelScale())));
}

static const float DepthTolerance = max(MB_DEPTH_TOLERANCE, 0.0001);

float TrailTapPhase(float2 uv)
{
#if MB_SAMPLE_JITTER && MB_DEBUG == 0
    // Use a stable screen-space phase for all taps at a pixel. Keeping their
    // spacing also keeps dense outer trails from skipping pixels.
    float2 pixel = floor(uv * ScreenSize);
    float3 phase = frac(pixel.xyx * 0.1031);
    phase += dot(phase, phase.yzx + 33.33);
    return frac((phase.x + phase.y) * phase.z);
#else
    return 0.5;
#endif
}

#if MB_USE_FOREGROUND
#include "Foreground.fxh"
#endif

#ifndef MB_EDGE_BACKGROUND
#define MB_EDGE_BACKGROUND 1
#endif

// Weight of one trail tap. Same-layer taps average the surface. With
// MB_EDGE_BACKGROUND, taps on empty space or on anything farther count as the
// background that shows through while the surface moves across this pixel, so
// the inner side of a silhouette fades like the outer side. Nearer taps are
// left to ExtendForeground; translucent taps stay excluded.
float TapWeight(float4 center, float4 sampleGeometry, float sampleAlpha)
{
    if (IsProtectedSurface(sampleGeometry.a)) {
        return 0.0;
    }
    if (!HasGeometryCoverage(sampleGeometry.a)) {
        return MB_EDGE_BACKGROUND ? 1.0 : 0.0;
    }
    float gap = sampleGeometry.b - center.b;
    float same = 1.0 - smoothstep(DepthTolerance, DepthTolerance * 2.0, abs(gap));
    float weight = same * sampleAlpha;
#if MB_EDGE_BACKGROUND
    if (!IsOrdinaryTranslucent(center.a) && !IsOrdinaryTranslucent(sampleGeometry.a)) {
        weight += smoothstep(DepthTolerance, DepthTolerance * 2.0, gap);
    }
#endif
    return weight;
}

// Tap count follows the streak length, so long streaks keep a fixed spacing
// instead of breaking into visible copies, and short ones cost less.
#if MB_QUALITY == 0
static const float TapSpacing = 4.0;
static const float MinTaps = 4.0;
static const float MaxTaps = 32.0;
#elif MB_QUALITY == 2
static const float TapSpacing = 1.0;
static const float MinTaps = 4.0;
static const float MaxTaps = 128.0;
#elif MB_QUALITY == 3
// 0.2.0 kernel: always 16 taps spread over the streak, for side-by-side tests.
static const float MaxTaps = 16.0;
#else
static const float TapSpacing = 2.0;
static const float MinTaps = 4.0;
static const float MaxTaps = 64.0;
#endif

float4 BlurSurface(float2 uv, float4 color, float4 geometry, float2 streak)
{
    bool outline = geometry.a > 3.5 && !IsAdditive(geometry.a);
    float streakLength = length(streak);
    if (streakLength < MinStreak() || (color.a <= 0.004 && !outline)) {
        return color;
    }

#if MB_QUALITY == 3
    int taps = (int)MaxTaps;
#else
    int taps = (int)clamp(ceil(streakLength / TapSpacing), MinTaps, StreakTapBudget(MaxTaps));
#endif
    // Keep the centre's share of the total the same as the old 16-tap kernel
    // (2/16 for surfaces, 0.75/16 for outlines).
    float weightSum = taps * (outline ? 0.046875 : 0.125);
#if MB_USE_TRAIL_ALPHA
    float4 sum = color * weightSum;
#else
    float3 sum = color.rgb * weightSum;
#endif
    float2 stepUV = streak / ScreenSize;
    float phase = TrailTapPhase(uv);
    // The tap budget varies with viewport height in the legacy effect compiler.
    [fastopt]
    for (int tap = 0; tap < taps; ++tap) {
        float t = (tap + phase) / taps - 0.5;
        float2 tapUV = uv + t * stepUV;
        float inside = all(tapUV >= 0.0) && all(tapUV < 1.0);
        // Both buffers carry the same log depth and coverage in B/A.
#if MB_USE_FOREGROUND
        float4 tapGeometry = tex2Dlod(MotionSampler, float4(tapUV, 0.0, 0.0));
#else
        float4 tapGeometry = tex2Dlod(GeometrySampler, float4(tapUV, 0.0, 0.0));
#endif
#if MB_TRANSLUCENT_MOTION
        // Keep color and depth on the same texel near translucent layers.
        float4 tapColor;
        [branch]
        if (IsOrdinaryTranslucent(geometry.a) || IsOrdinaryTranslucent(tapGeometry.a)) {
            tapColor = tex2Dlod(SceneSampler, float4(tapUV, 0.0, 0.0));
        } else {
            tapColor = tex2Dlod(SceneTapSampler, float4(tapUV, 0.0, 0.0));
        }
#else
        float4 tapColor = tex2Dlod(SceneTapSampler, float4(tapUV, 0.0, 0.0));
#endif
#if MB_USE_TRAIL_ALPHA
        // Capture already stores premultiplied color, so average RGBA with the same weights.
        float weight = inside * TapWeight(geometry, tapGeometry, 1.0);
        sum += tapColor * weight;
#else
        float alpha = tapGeometry.a > 3.5 && !IsAdditive(tapGeometry.a) ? 1.0 : tapColor.a;
        float weight = inside * TapWeight(geometry, tapGeometry, alpha);
        sum += tapColor.rgb * weight;
#endif
        weightSum += weight;
    }
#if MB_USE_TRAIL_ALPHA
    return sum / weightSum;
#else
    return float4(sum / weightSum, color.a);
#endif
}

float4 Reconstruct(float2 quadUV : TEXCOORD0) : COLOR0
{
    // MME can draw to a viewport whose origin is inside the MMD window.
    float2 uv = quadUV + 0.5 / ScreenSize;
    float4 color = tex2Dlod(SceneSampler, float4(uv, 0.0, 0.0));
#if MB_DEBUG == 1
    return color;
#elif MB_USE_FOREGROUND
    float4 geometry = tex2Dlod(MotionSampler, float4(uv, 0.0, 0.0));
    float4 blurred = BlurSurface(uv, color, geometry, geometry.rg);
    return ExtendForeground(uv, blurred, geometry);
#else
    float4 geometry = tex2Dlod(GeometrySampler, float4(uv, 0.0, 0.0));
#if MB_DEBUG == 3
    float depth = saturate((geometry.b + 2.0) / 11.0);
    return float4(depth.xxx * HasGeometryCoverage(geometry.a), 1.0);
#elif MB_DEBUG == 4
    if (IsOrdinaryTranslucent(geometry.a) || IsAdditive(geometry.a)) {
        return float4(1.0, 0.0, 0.0, 1.0);
    }
    if (geometry.a > 3.5) {
        return float4(1.0, 1.0, 0.0, 1.0);
    }
    bool modelMotion = HasModelMotion(geometry.a, CurrentCameraAnalysis().x);
    return float4(geometry.a > 2.5, modelMotion, geometry.a > 0.0 && geometry.a < 2.5 && !modelMotion, 1.0);
#else
    float4 camera = CurrentCameraAnalysis();
    float2 streak = ExposureStreak(quadUV, geometry, camera);
#if MB_DEBUG == 2
    float limit = max(MotionStreakLimit(), 1.0);
    return float4(0.5 + 0.5 * clamp(streak / limit, -1.0, 1.0),
                  saturate(length(streak) / limit), 1.0);
#else
    return BlurSurface(uv, color, geometry, streak);
#endif
#endif
#endif
}

#define MB_SCREEN_STATE \
    AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE; \
    ZEnable = FALSE; ZWriteEnable = FALSE; CullMode = NONE; FillMode = SOLID; \
    StencilEnable = FALSE; SRGBWriteEnable = FALSE; ColorWriteEnable = 15; \
    VertexShader = compile vs_3_0 ScreenQuad();

technique AdvancedMotionBlur <
    string Script =
        "RenderColorTarget0=SceneColor;"
        "RenderDepthStencilTarget=SceneDepth;"
        "ClearSetColor=SceneClear;"
        "ClearSetDepth=DepthClear;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        "RenderColorTarget0=CameraAnalysis;"
        "RenderDepthStencilTarget=AnalysisDepth;"
        "Pass=AnalyzeCamera;"
#if MB_USE_FOREGROUND
        "RenderColorTarget0=MotionField;"
        "RenderDepthStencilTarget=SceneDepth;"
        "Pass=BuildMotion;"
        "RenderColorTarget0=TileRows;"
        "RenderDepthStencilTarget=TileRowsDepth;"
        "Pass=ReduceTileRows;"
        "RenderColorTarget0=TileMax;"
        "RenderDepthStencilTarget=TileDepth;"
        "Pass=ReduceTiles;"
        "RenderColorTarget0=NeighborMax;"
        "Pass=ReduceNeighbors;"
#endif
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "Pass=Output;"
#if MB_KEEP_OBJECT_MOTION_ON_CUT
        // Clear for the next auxiliary scene render, after every consumer is done.
        "RenderColorTarget0=AMB_CutMotion;"
        "RenderDepthStencilTarget=SceneDepth;"
        "ClearSetColor=CutMotionClear;"
        "Clear=Color;"
#endif
        "RenderColorTarget0=AMB_CameraHistory;"
        "RenderDepthStencilTarget=CameraDepth;"
        "Pass=SaveCamera;"
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;";
> {
    pass AnalyzeCamera < string Script = "Draw=Buffer;"; > {
        MB_SCREEN_STATE
        PixelShader = compile ps_3_0 AnalyzeCameraFrame();
    }
#if MB_USE_FOREGROUND
    pass BuildMotion < string Script = "Draw=Buffer;"; > {
        MB_SCREEN_STATE
        PixelShader = compile ps_3_0 BuildMotionField();
    }
    pass ReduceTileRows < string Script = "Draw=Buffer;"; > {
        MB_SCREEN_STATE
        PixelShader = compile ps_3_0 BuildTileRows();
    }
    pass ReduceTiles < string Script = "Draw=Buffer;"; > {
        MB_SCREEN_STATE
        PixelShader = compile ps_3_0 BuildTileMax();
    }
    pass ReduceNeighbors < string Script = "Draw=Buffer;"; > {
        MB_SCREEN_STATE
        PixelShader = compile ps_3_0 BuildNeighborMax();
    }
#endif
    pass Output < string Script = "Draw=Buffer;"; > {
        MB_SCREEN_STATE
        PixelShader = compile ps_3_0 Reconstruct();
    }
    pass SaveCamera < string Script = "Draw=Buffer;"; > {
        MB_SCREEN_STATE
        PixelShader = compile ps_3_0 StoreCamera();
    }
}
