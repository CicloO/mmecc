#include "Settings.fxh"

#ifndef MB_RIGID_HISTORY
#define MB_RIGID_HISTORY 0
#endif
#define MB_GEOMETRY_HISTORY (MB_VERTEX_HISTORY || MB_RIGID_HISTORY)

#if MB_KEEP_OBJECT_MOTION_ON_CUT || MB_RIGID_HISTORY
#include "HistoryTargets.fxh"
#endif

#if MB_KEEP_OBJECT_MOTION_ON_CUT
#define MB_CUT_TARGET_ON "RenderColorTarget0=;RenderDepthStencilTarget=;RenderColorTarget1=AMB_CutMotion;"
#define MB_CUT_TARGET_OFF "RenderColorTarget1=;"
#define MB_CUT_TARGET_STATE ColorWriteEnable1 = 15;
#else
#define MB_CUT_TARGET_ON ""
#define MB_CUT_TARGET_OFF ""
#define MB_CUT_TARGET_STATE
#endif

float4x4 ObjectToClip : WORLDVIEWPROJECTION;
float4x4 ObjectToView : WORLDVIEW;
float4 MaterialColor : DIFFUSE < string Object = "Geometry"; >;
bool use_texture;
bool opadd;
texture MaterialMap : MATERIALTEXTURE;

sampler2D MaterialSampler = sampler_state {
    Texture = <MaterialMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
};

#if MB_GEOMETRY_HISTORY
#include "Fullscreen.fxh"

float2 TargetSize : VIEWPORTPIXELSIZE;
float Timeline : TIME < bool SyncInEditMode = true; >;
#define MB_HISTORY_FILTER \
    MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; \
    AddressU = CLAMP; AddressV = CLAMP; SRGBTexture = FALSE;
#endif

#if MB_VERTEX_HISTORY
int VertexCount;

texture CurrentVertices : RENDERCOLORTARGET <
    int Width = MB_HISTORY_SIZE;
    int Height = MB_HISTORY_SIZE;
    string Format = "A32B32G32R32F";
>;
texture PreviousVertices : RENDERCOLORTARGET <
    int Width = MB_HISTORY_SIZE;
    int Height = MB_HISTORY_SIZE;
    string Format = "A32B32G32R32F";
>;
texture AtlasDepth : RENDERDEPTHSTENCILTARGET <
    int Width = MB_HISTORY_SIZE;
    int Height = MB_HISTORY_SIZE;
>;

sampler2D CurrentSampler = sampler_state { Texture = <CurrentVertices>; MB_HISTORY_FILTER };
sampler2D PreviousSampler = sampler_state { Texture = <PreviousVertices>; MB_HISTORY_FILTER };

float2 AtlasCell(int index)
{
    float row = floor((float)index / MB_HISTORY_SIZE);
    return float2(index - row * MB_HISTORY_SIZE, row);
}

bool FitsAtlas(int index)
{
    return VertexCount <= MB_HISTORY_SIZE * MB_HISTORY_SIZE
        && index >= 0 && index < MB_HISTORY_SIZE * MB_HISTORY_SIZE;
}
#endif

#if MB_RIGID_HISTORY || (MB_VERTEX_HISTORY && (MB_DEBUG == 5 || MB_KEEP_OBJECT_MOTION_ON_CUT))
float4x4 ObjectToWorld : WORLD;
float4x4 WorldToClip : VIEWPROJECTION;
#endif

#if MB_RIGID_HISTORY || (MB_VERTEX_HISTORY && MB_KEEP_OBJECT_MOTION_ON_CUT)
sampler2D HistoryCameraSampler = sampler_state { Texture = <AMB_CameraHistory>; MB_HISTORY_FILTER };

float4 HistoryCameraSlot(float index)
{
    return tex2Dlod(HistoryCameraSampler, float4((index + 0.5) / 8.0, 0.5, 0.0, 0.0));
}

float4x4 HistoryViewProjection()
{
    return float4x4(HistoryCameraSlot(0.0), HistoryCameraSlot(1.0), HistoryCameraSlot(2.0), HistoryCameraSlot(3.0));
}

bool HistoryTeleported(float3 shift)
{
    return MB_TELEPORT_DISTANCE > 0.0
        && dot(shift, shift) > MB_TELEPORT_DISTANCE * MB_TELEPORT_DISTANCE;
}

float4 ReprojectHistory(float4 world, float4x4 camera)
{
    float4 clipPosition = mul(world, camera);
    return clipPosition.w > 0.0001 ? float4(clipPosition.xyw, 1.0) : 0.0;
}
#endif

#if MB_RIGID_HISTORY
#include "RigidHistory.fxh"
#endif

#if MB_DEBUG == 5 && MB_GEOMETRY_HISTORY
float ProjectionError(float4 expected, float4 projected)
{
    if (expected.w <= 0.0001 || projected.w <= 0.0001) {
        return 65504.0;
    }
    float2 delta = (expected.xy / expected.w - projected.xy / projected.w) * (0.5 * TargetSize);
    return min(length(delta), 65504.0);
}
#endif

struct GeometryOutput {
    float4 position : POSITION;
    float2 uv : TEXCOORD0;
    float viewDepth : TEXCOORD1;
#if MB_GEOMETRY_HISTORY
    float4 previousClip : TEXCOORD2;
    float3 currentClip : TEXCOORD3;
#endif
#if MB_DEBUG == 5 && MB_GEOMETRY_HISTORY
    float2 projectionError : TEXCOORD4;
#endif
#if MB_KEEP_OBJECT_MOTION_ON_CUT && MB_GEOMETRY_HISTORY
    float4 previousLocalClip : TEXCOORD5;
#endif
};

GeometryOutput ProjectGeometry(float4 position : POSITION, float2 uv : TEXCOORD0
#if MB_VERTEX_HISTORY
                               , int index : _INDEX
#endif
                               )
{
    GeometryOutput output;
    output.position = mul(position, ObjectToClip);
    output.uv = uv;
    output.viewDepth = mul(position, ObjectToView).z;
#if MB_DEBUG == 5 && MB_GEOMETRY_HISTORY
    output.projectionError = float2(
        ProjectionError(output.position, mul(position, WorldToClip)),
        ProjectionError(output.position, mul(mul(position, ObjectToWorld), WorldToClip)));
#endif
#if MB_VERTEX_HISTORY
    float2 atlasUV = (AtlasCell(index) + 0.5) / MB_HISTORY_SIZE;
    float4 stored = tex2Dlod(PreviousSampler, float4(atlasUV, 0.0, 0.0));
#if MB_KEEP_OBJECT_MOTION_ON_CUT
    // World histories carry a negative timestamp, so an older clip-space atlas
    // cannot be mistaken for world positions after a reload.
    float previousTime = -stored.w - 1.0;
    float dt = Timeline - previousTime;
    float4 cameraTiming = HistoryCameraSlot(4.0);
    bool valid = FitsAtlas(index) && stored.w <= -1.0
        && dt > MB_MIN_FRAME_GAP && dt <= MB_MAX_FRAME_GAP
        && cameraTiming.w == CameraHistoryTag && abs(cameraTiming.x - previousTime) <= MB_MIN_FRAME_GAP;
    float3 shift = mul(position, ObjectToWorld).xyz - stored.xyz;
    output.previousClip = 0.0;
    output.previousLocalClip = 0.0;
    if (valid && !HistoryTeleported(shift)) {
        float4 world = float4(stored.xyz, 1.0);
        output.previousClip = ReprojectHistory(world, HistoryViewProjection());
        output.previousLocalClip = ReprojectHistory(world, WorldToClip);
    }
#else
    float dt = Timeline - (stored.w - 1.0);
    bool valid = FitsAtlas(index) && stored.w >= 1.0 && stored.z > 0.0001
        && dt > MB_MIN_FRAME_GAP && dt <= MB_MAX_FRAME_GAP;
    output.previousClip = valid ? float4(stored.xyz, 1.0) : 0.0;
#endif
#elif MB_RIGID_HISTORY
    float4 previousWorld = RigidPreviousWorld(position);
    output.previousClip = 0.0;
#if MB_KEEP_OBJECT_MOTION_ON_CUT
    output.previousLocalClip = 0.0;
#endif
    if (previousWorld.w > 0.5) {
        output.previousClip = ReprojectHistory(previousWorld, HistoryViewProjection());
#if MB_KEEP_OBJECT_MOTION_ON_CUT
        output.previousLocalClip = ReprojectHistory(previousWorld, WorldToClip);
#endif
    }
#endif
#if MB_GEOMETRY_HISTORY
    output.currentClip = output.position.xyw;
#endif
    return output;
}

float MaterialCoverage(float2 uv)
{
    float alpha = MaterialColor.a;
    if (use_texture) {
        alpha *= tex2D(MaterialSampler, uv).a;
    }
    return alpha;
}

#if MB_GEOMETRY_HISTORY
float2 GeometryMotion(float3 currentClip, float3 previousClip)
{
    float2 now = currentClip.xy / currentClip.z;
    float2 then = previousClip.xy / previousClip.z;
    return clamp((now - then) * float2(0.5, -0.5) * TargetSize, -16384.0, 16384.0);
}
#endif

float4 SurfaceDepth(GeometryOutput input)
{
    float alpha = MaterialCoverage(input.uv);
    clip(alpha - 0.004);
    float depth = log2(max(input.viewDepth, 0.0001));
#if MB_DEBUG == 5 && MB_GEOMETRY_HISTORY
    return float4(input.projectionError, depth, 5.0);
#else
    float coverage = (alpha >= 0.985 && !opadd) ? 1.0 : 3.0;
#if MB_GEOMETRY_HISTORY
    if (coverage == 1.0 && input.previousClip.w > 0.999 && input.currentClip.z > 0.0001) {
        return float4(GeometryMotion(input.currentClip, input.previousClip.xyz), depth, 2.0);
    }
#endif
    return float4(0.0, 0.0, depth, coverage);
#endif
}

#if MB_KEEP_OBJECT_MOTION_ON_CUT
struct DepthTargets {
    float4 primary : COLOR0;
    float4 cutMotion : COLOR1;
};

DepthTargets DepthPixel(GeometryOutput input)
{
    DepthTargets output;
    output.primary = SurfaceDepth(input);
    output.cutMotion = 0.0;
#if MB_GEOMETRY_HISTORY
    if (output.primary.a <= 2.5 && input.previousLocalClip.w > 0.999 && input.currentClip.z > 0.0001) {
        float2 motion = GeometryMotion(input.currentClip, input.previousLocalClip.xyz);
        output.cutMotion = float4(motion, output.primary.b, 1.0);
    }
#endif
    return output;
}
#else
float4 DepthPixel(GeometryOutput input) : COLOR0
{
    return SurfaceDepth(input);
}
#endif

#define MB_GEOMETRY_STATE \
    AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE; \
    ZEnable = TRUE; ZWriteEnable = TRUE; ZFunc = LESSEQUAL; \
    CullMode = NONE; FillMode = SOLID; StencilEnable = FALSE; \
    SRGBWriteEnable = FALSE; ColorWriteEnable = 15; \
    MB_CUT_TARGET_STATE \
    VertexShader = compile vs_3_0 ProjectGeometry(); \
    PixelShader = compile ps_3_0 DepthPixel();

#if MB_GEOMETRY_HISTORY
#define MB_HISTORY_WRITE_STATE \
    AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE; \
    ZEnable = FALSE; ZWriteEnable = FALSE; CullMode = NONE; \
    StencilEnable = FALSE; SRGBWriteEnable = FALSE; ColorWriteEnable = 15;
#endif

#if MB_VERTEX_HISTORY
struct AtlasVertex {
    float4 position : POSITION;
    float4 data : TEXCOORD0;
};

AtlasVertex RecordVertex(float4 position : POSITION, int index : _INDEX)
{
    AtlasVertex output;
    float2 cell = AtlasCell(index);
    float2 clipXY = (cell * (2.0 / MB_HISTORY_SIZE) - 1.0) * float2(1.0, -1.0);
    output.position = FitsAtlas(index) ? float4(clipXY, 0.0, 1.0) : float4(4.0, 4.0, 0.0, 1.0);
#if MB_KEEP_OBJECT_MOTION_ON_CUT
    output.data = float4(mul(position, ObjectToWorld).xyz, -(Timeline + 1.0));
#else
    output.data = float4(mul(position, ObjectToClip).xyw, Timeline + 1.0);
#endif
    return output;
}

float4 RecordPixel(float4 data : TEXCOORD0) : COLOR0
{
    return data;
}

float4 CopyAtlas(float2 quadUV : TEXCOORD0) : COLOR0
{
    float2 uv = quadUV + 0.5 / MB_HISTORY_SIZE;
    return tex2Dlod(CurrentSampler, float4(uv, 0.0, 0.0));
}

// All materials in this object read the snapshot captured before subset zero.
#define MB_COPY_SCRIPT \
    "RenderColorTarget0=PreviousVertices;" \
    "RenderDepthStencilTarget=AtlasDepth;" \
    "Pass=CopyHistory;" \
    "RenderColorTarget0=;" \
    "RenderDepthStencilTarget=;"
#define MB_RECORD_SCRIPT \
    MB_CUT_TARGET_ON \
    "Pass=WriteGeometry;" \
    MB_CUT_TARGET_OFF \
    "RenderColorTarget0=CurrentVertices;" \
    "RenderDepthStencilTarget=AtlasDepth;" \
    "Pass=RecordHistory;"
#define MB_COPY_PASS \
    pass CopyHistory < string Script = "Draw=Buffer;"; > { \
        MB_HISTORY_WRITE_STATE \
        FillMode = SOLID; \
        VertexShader = compile vs_3_0 ScreenQuad(); \
        PixelShader = compile ps_3_0 CopyAtlas(); \
    }
#define MB_RECORD_PASSES \
    pass WriteGeometry < string Script = "Draw=Geometry;"; > { MB_GEOMETRY_STATE } \
    pass RecordHistory < string Script = "Draw=Geometry;"; > { \
        MB_HISTORY_WRITE_STATE \
        FillMode = POINT; PointSize = 1.0; PointScaleEnable = FALSE; \
        VertexShader = compile vs_3_0 RecordVertex(); \
        PixelShader = compile ps_3_0 RecordPixel(); \
    }

technique GeometryFirst <
    string MMDPass = "object";
    string Subset = "0";
    string Script = MB_COPY_SCRIPT MB_RECORD_SCRIPT;
> {
    MB_COPY_PASS
    MB_RECORD_PASSES
}

technique GeometryFirstSS <
    string MMDPass = "object_ss";
    string Subset = "0";
    string Script = MB_COPY_SCRIPT MB_RECORD_SCRIPT;
> {
    MB_COPY_PASS
    MB_RECORD_PASSES
}

technique Geometry < string MMDPass = "object"; string Script = MB_RECORD_SCRIPT; > {
    MB_RECORD_PASSES
}

technique GeometrySS < string MMDPass = "object_ss"; string Script = MB_RECORD_SCRIPT; > {
    MB_RECORD_PASSES
}
#endif

#if !MB_VERTEX_HISTORY
#define MB_DRAW_SCRIPT MB_CUT_TARGET_ON "Pass=WriteGeometry;" MB_CUT_TARGET_OFF
#define MB_DRAW_PASS pass WriteGeometry < string Script = "Draw=Geometry;"; > { MB_GEOMETRY_STATE }
#if MB_RIGID_HISTORY
#define MB_RIGID_SCRIPT \
    "RenderColorTarget0=PreviousRigid;" \
    "RenderDepthStencilTarget=RigidDepth;" \
    "Pass=CopyRigidHistory;" \
    "RenderColorTarget0=CurrentRigid;" \
    "Pass=RecordRigidHistory;" \
    "RenderColorTarget0=;" \
    "RenderDepthStencilTarget=;" \
    MB_DRAW_SCRIPT
#define MB_RIGID_PASSES \
    pass CopyRigidHistory < string Script = "Draw=Buffer;"; > { \
        MB_HISTORY_WRITE_STATE \
        FillMode = SOLID; \
        VertexShader = compile vs_3_0 ScreenQuad(); \
        PixelShader = compile ps_3_0 CopyRigid(); \
    } \
    pass RecordRigidHistory < string Script = "Draw=Buffer;"; > { \
        MB_HISTORY_WRITE_STATE \
        FillMode = SOLID; \
        VertexShader = compile vs_3_0 ScreenQuad(); \
        PixelShader = compile ps_3_0 RecordRigid(); \
    }

technique GeometryFirst < string MMDPass = "object"; string Subset = "0"; string Script = MB_RIGID_SCRIPT; > {
    MB_RIGID_PASSES
    MB_DRAW_PASS
}
technique GeometryFirstSS < string MMDPass = "object_ss"; string Subset = "0"; string Script = MB_RIGID_SCRIPT; > {
    MB_RIGID_PASSES
    MB_DRAW_PASS
}
#endif

#if MB_RIGID_HISTORY || MB_KEEP_OBJECT_MOTION_ON_CUT
technique Geometry < string MMDPass = "object"; string Script = MB_DRAW_SCRIPT; > { MB_DRAW_PASS }
technique GeometrySS < string MMDPass = "object_ss"; string Script = MB_DRAW_SCRIPT; > { MB_DRAW_PASS }
#else
technique Geometry < string MMDPass = "object"; > { pass WriteGeometry { MB_GEOMETRY_STATE } }
technique GeometrySS < string MMDPass = "object_ss"; > { pass WriteGeometry { MB_GEOMETRY_STATE } }
#endif
#endif

#if MB_EXTEND_FOREGROUND && MB_OUTLINE_MOTION
float4 OutlineColor : EDGECOLOR;

struct OutlineOutput {
    float4 position : POSITION;
    float viewDepth : TEXCOORD0;
};

OutlineOutput ProjectOutline(float4 position : POSITION)
{
    // MMD's edge pass already supplies the expanded hull vertices.
    OutlineOutput output;
    output.position = mul(position, ObjectToClip);
    output.viewDepth = mul(position, ObjectToView).z;
    return output;
}

float4 OutlineSurfaceDepth(OutlineOutput input)
{
    clip(OutlineColor.a - 0.004);
    float coverage = OutlineColor.a >= 0.985 ? 4.0 : 3.0;
    return float4(0.0, 0.0, log2(max(input.viewDepth, 0.0001)), coverage);
}

#if MB_KEEP_OBJECT_MOTION_ON_CUT
DepthTargets OutlineDepth(OutlineOutput input)
{
    DepthTargets output;
    output.primary = OutlineSurfaceDepth(input);
    output.cutMotion = 0.0;
    return output;
}
#else
float4 OutlineDepth(OutlineOutput input) : COLOR0
{
    return OutlineSurfaceDepth(input);
}
#endif

technique OutlineGeometry <
    string MMDPass = "edge";
#if MB_KEEP_OBJECT_MOTION_ON_CUT
    string Script = MB_CUT_TARGET_ON "Pass=WriteOutline;" MB_CUT_TARGET_OFF;
#endif
> {
    pass WriteOutline < string Script = "Draw=Geometry;"; > {
        AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
        ZEnable = TRUE; ZWriteEnable = TRUE; ZFunc = LESS;
        CullMode = CW; FillMode = SOLID; StencilEnable = FALSE;
        SRGBWriteEnable = FALSE; ColorWriteEnable = 15;
        MB_CUT_TARGET_STATE
        VertexShader = compile vs_3_0 ProjectOutline();
        PixelShader = compile ps_3_0 OutlineDepth();
    }
}
#else
technique NoEdge < string MMDPass = "edge"; > {}
#endif
technique NoShadow < string MMDPass = "shadow"; > {}
technique NoZPlot < string MMDPass = "zplot"; > {}
