#include "Settings.fxh"

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

float2 ScreenSize : VIEWPORTPIXELSIZE;
float4x4 ViewProjection : VIEWPROJECTION;
float4x4 InverseViewProjection : VIEWPROJECTIONINVERSE;
float4x4 View : VIEW;
float4x4 Projection : PROJECTION;
float Timeline : TIME < bool SyncInEditMode = true; >;
float AccessoryScale : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

float4 SceneClear = {MB_CLEAR_RGBA};
float DepthClear = 1.0;

texture SceneColor : RENDERCOLORTARGET < string Format = "A8R8G8B8"; >;
texture SceneDepth : RENDERDEPTHSTENCILTARGET;
texture CameraState : RENDERCOLORTARGET <
    int Width = 8;
    int Height = 1;
    string Format = "A32B32G32R32F";
>;
texture CameraDepth : RENDERDEPTHSTENCILTARGET < int Width = 8; int Height = 1; >;

texture GeometryData : OFFSCREENRENDERTARGET <
    string Description = "AdvancedMotionBlur - depth and motion";
    string Format = "A16B16G16R16F";
    float4 ClearColor = {0.0, 0.0, 0.0, 0.0};
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    string DefaultEffect = "self=hide; *=DepthVelocity.fx;";
>;

#define MB_POINT_FILTER \
    MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; \
    AddressU = CLAMP; AddressV = CLAMP; SRGBTexture = FALSE;
sampler2D SceneSampler = sampler_state { Texture = <SceneColor>; MB_POINT_FILTER };
sampler2D CameraSampler = sampler_state { Texture = <CameraState>; MB_POINT_FILTER };
sampler2D GeometrySampler = sampler_state { Texture = <GeometryData>; MB_POINT_FILTER };

float4 ScreenQuad(float4 position : POSITION) : POSITION
{
    return position;
}

float3 CameraForward()
{
    return float3(View[0][2], View[1][2], View[2][2]);
}

float3 CameraUp()
{
    return float3(View[0][1], View[1][1], View[2][1]);
}

float4 StoreCamera(float2 pixel : VPOS) : COLOR0
{
    int slot = (int)pixel.x;
    if (slot < 4) {
        return ViewProjection[slot];
    }
    if (slot == 4) {
        return float4(Timeline, ScreenSize, 319.25);
    }
    if (slot == 5) {
        return float4(CameraForward(), Projection[1][1]);
    }
    return float4(CameraUp(), Projection[2][3]);
}

float4 PreviousCamera(float slot)
{
    return tex2Dlod(CameraSampler, float4((slot + 0.5) / 8.0, 0.5, 0.0, 0.0));
}

float CameraInterval()
{
    float4 timing = PreviousCamera(4.0);
    float dt = Timeline - timing.x;
    if (timing.w != 319.25 || any(abs(timing.yz - ScreenSize) > 0.5)
        || !(dt > 0.001 && dt <= MB_MAX_FRAME_GAP)) {
        return 0.0;
    }
    float4 previousForward = PreviousCamera(5.0);
    float4 previousUp = PreviousCamera(6.0);
    float zoomRatio = Projection[1][1] / max(previousForward.w, 0.0001);
    if (dot(previousForward.xyz, CameraForward()) < MB_CUT_ANGLE_COS
        || dot(previousUp.xyz, CameraUp()) < MB_CUT_ANGLE_COS
        || zoomRatio < 0.75 || zoomRatio > 1.33
        || abs(previousUp.w - Projection[2][3]) > 0.5) {
        return 0.0;
    }
    return dt;
}

float2 CameraDisplacement(float2 uv, float logDepth)
{
    float depth = exp2(logDepth);
    float4 projectionZW = mul(float4(0.0, 0.0, depth, 1.0), Projection);
    float2 ndc = (uv * 2.0 - 1.0) * float2(1.0, -1.0);
    float4 currentClip = float4(ndc * projectionZW.w, projectionZW.zw);
    float4 world = mul(currentClip, InverseViewProjection);
    float4 oldClip = mul(world, float4x4(
        PreviousCamera(0.0), PreviousCamera(1.0), PreviousCamera(2.0), PreviousCamera(3.0)));
    if (oldClip.w < 0.0001) {
        return 0.0;
    }
    return (ndc - oldClip.xy / oldClip.w) * float2(0.5, -0.5) * ScreenSize;
}

float2 ExposureStreak(float2 uv, float4 geometry, float dt)
{
    if (dt <= 0.0 || geometry.a < 0.5 || geometry.a > 2.5) {
        return 0.0;
    }
    float2 delta = geometry.a > 1.5 ? geometry.rg : CameraDisplacement(uv, geometry.b);
    float distance = length(delta);
    if (!(distance >= 0.01 && distance < length(ScreenSize) * 0.65)) {
        return 0.0;
    }
    float shutter = saturate(MB_SHUTTER_ANGLE / 360.0);
    float scale = max(0.0, AccessoryScale * 0.1 * MB_MOTION_SCALE);
    float extent = min(MB_MAX_STREAK, distance * shutter * scale / (dt * max(MB_OUTPUT_FPS, 1.0)));
    return delta * (extent / distance);
}

float DepthWeight(float4 center, float4 sampleGeometry)
{
    if (sampleGeometry.a < 0.5 || sampleGeometry.a > 2.5) {
        return 0.0;
    }
    float gap = abs(center.b - sampleGeometry.b);
    float tolerance = max(MB_DEPTH_TOLERANCE, 0.0001);
    return 1.0 - smoothstep(tolerance, tolerance * 2.0, gap);
}

#if MB_QUALITY == 0
#define MB_TAPS 8
#elif MB_QUALITY == 2
#define MB_TAPS 24
#else
#define MB_TAPS 16
#endif

float4 Reconstruct(float2 pixel : VPOS) : COLOR0
{
    float2 uv = (pixel + 0.5) / ScreenSize;
    float4 color = tex2Dlod(SceneSampler, float4(uv, 0.0, 0.0));
#if MB_DEBUG == 1
    return color;
#endif
    float4 geometry = tex2Dlod(GeometrySampler, float4(uv, 0.0, 0.0));
#if MB_DEBUG == 3
    float depth = saturate((geometry.b + 2.0) / 11.0);
    return float4(depth.xxx * step(0.5, geometry.a), 1.0);
#elif MB_DEBUG == 4
    return float4(geometry.a > 2.5, geometry.a > 1.5 && geometry.a < 2.5,
                  geometry.a > 0.5 && geometry.a < 1.5, 1.0);
#endif
    float2 streak = ExposureStreak(uv, geometry, CameraInterval());
#if MB_DEBUG == 2
    return float4(0.5 + 0.5 * clamp(streak / max(MB_MAX_STREAK, 1.0), -1.0, 1.0),
                  saturate(length(streak) / max(MB_MAX_STREAK, 1.0)), 1.0);
#endif
    if (length(streak) < 0.75 || color.a <= 0.004) {
        return color;
    }

    float3 sum = color.rgb * 2.0;
    float weightSum = 2.0;
    float2 stepUV = streak / ScreenSize;
    [loop]
    for (int tap = 0; tap < MB_TAPS; ++tap) {
        float t = (tap + 0.5) / MB_TAPS - 0.5;
        float2 tapUV = uv + t * stepUV;
        float inside = all(tapUV >= 0.0) && all(tapUV < 1.0);
        float4 tapGeometry = tex2Dlod(GeometrySampler, float4(tapUV, 0.0, 0.0));
        float4 tapColor = tex2Dlod(SceneSampler, float4(tapUV, 0.0, 0.0));
        float weight = inside * DepthWeight(geometry, tapGeometry) * tapColor.a;
        sum += tapColor.rgb * weight;
        weightSum += weight;
    }
    return float4(sum / weightSum, color.a);
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
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "Pass=Output;"
        "RenderColorTarget0=CameraState;"
        "RenderDepthStencilTarget=CameraDepth;"
        "Pass=SaveCamera;"
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;";
> {
    pass Output < string Script = "Draw=Buffer;"; > {
        MB_SCREEN_STATE
        PixelShader = compile ps_3_0 Reconstruct();
    }
    pass SaveCamera < string Script = "Draw=Buffer;"; > {
        MB_SCREEN_STATE
        PixelShader = compile ps_3_0 StoreCamera();
    }
}
