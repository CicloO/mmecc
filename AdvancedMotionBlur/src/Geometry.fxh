#include "Settings.fxh"

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

#if MB_VERTEX_HISTORY
#include "Fullscreen.fxh"

float2 TargetSize : VIEWPORTPIXELSIZE;
float Timeline : TIME < bool SyncInEditMode = true; >;
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

#define MB_ATLAS_FILTER \
    MinFilter = POINT; MagFilter = POINT; MipFilter = NONE; \
    AddressU = CLAMP; AddressV = CLAMP; SRGBTexture = FALSE;
sampler2D CurrentSampler = sampler_state { Texture = <CurrentVertices>; MB_ATLAS_FILTER };
sampler2D PreviousSampler = sampler_state { Texture = <PreviousVertices>; MB_ATLAS_FILTER };

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

struct GeometryOutput {
    float4 position : POSITION;
    float2 uv : TEXCOORD0;
    float viewDepth : TEXCOORD1;
#if MB_VERTEX_HISTORY
    float4 previousClip : TEXCOORD2;
    float3 currentClip : TEXCOORD3;
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
#if MB_VERTEX_HISTORY
    float2 atlasUV = (AtlasCell(index) + 0.5) / MB_HISTORY_SIZE;
    float4 stored = tex2Dlod(PreviousSampler, float4(atlasUV, 0.0, 0.0));
    float dt = Timeline - (stored.w - 1.0);
    bool valid = FitsAtlas(index) && stored.w >= 1.0 && stored.z > 0.0001
        && dt > MB_MIN_FRAME_GAP && dt <= MB_MAX_FRAME_GAP;
    output.previousClip = valid ? float4(stored.xyz, 1.0) : 0.0;
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

float4 DepthPixel(GeometryOutput input) : COLOR0
{
    float alpha = MaterialCoverage(input.uv);
    clip(alpha - 0.004);
    float depth = log2(max(input.viewDepth, 0.0001));
    float coverage = (alpha >= 0.985 && !opadd) ? 1.0 : 3.0;
#if MB_VERTEX_HISTORY
    if (coverage == 1.0 && input.previousClip.w > 0.999 && input.currentClip.z > 0.0001) {
        float2 now = input.currentClip.xy / input.currentClip.z;
        float2 then = input.previousClip.xy / input.previousClip.z;
        float2 motion = (now - then) * float2(0.5, -0.5) * TargetSize;
        return float4(clamp(motion, -16384.0, 16384.0), depth, 2.0);
    }
#endif
    return float4(0.0, 0.0, depth, coverage);
}

#define MB_GEOMETRY_STATE \
    AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE; \
    ZEnable = TRUE; ZWriteEnable = TRUE; ZFunc = LESSEQUAL; \
    CullMode = NONE; FillMode = SOLID; StencilEnable = FALSE; \
    SRGBWriteEnable = FALSE; ColorWriteEnable = 15; \
    VertexShader = compile vs_3_0 ProjectGeometry(); \
    PixelShader = compile ps_3_0 DepthPixel();

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
    float4 projected = mul(position, ObjectToClip);
    output.data = float4(projected.xyw, Timeline + 1.0);
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

#define MB_ATLAS_STATE \
    AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE; \
    ZEnable = FALSE; ZWriteEnable = FALSE; CullMode = NONE; \
    StencilEnable = FALSE; SRGBWriteEnable = FALSE; ColorWriteEnable = 15;

// All materials in this object read the snapshot captured before subset zero.
#define MB_COPY_SCRIPT \
    "RenderColorTarget0=PreviousVertices;" \
    "RenderDepthStencilTarget=AtlasDepth;" \
    "Pass=CopyHistory;" \
    "RenderColorTarget0=;" \
    "RenderDepthStencilTarget=;"
#define MB_RECORD_SCRIPT \
    "Pass=WriteGeometry;" \
    "RenderColorTarget0=CurrentVertices;" \
    "RenderDepthStencilTarget=AtlasDepth;" \
    "Pass=RecordHistory;"
#define MB_COPY_PASS \
    pass CopyHistory < string Script = "Draw=Buffer;"; > { \
        MB_ATLAS_STATE \
        FillMode = SOLID; \
        VertexShader = compile vs_3_0 ScreenQuad(); \
        PixelShader = compile ps_3_0 CopyAtlas(); \
    }
#define MB_RECORD_PASSES \
    pass WriteGeometry < string Script = "Draw=Geometry;"; > { MB_GEOMETRY_STATE } \
    pass RecordHistory < string Script = "Draw=Geometry;"; > { \
        MB_ATLAS_STATE \
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
#else
technique Geometry < string MMDPass = "object"; > {
    pass WriteGeometry { MB_GEOMETRY_STATE }
}
technique GeometrySS < string MMDPass = "object_ss"; > {
    pass WriteGeometry { MB_GEOMETRY_STATE }
}
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

float4 OutlineDepth(OutlineOutput input) : COLOR0
{
    clip(OutlineColor.a - 0.004);
    float coverage = OutlineColor.a >= 0.985 ? 4.0 : 3.0;
    return float4(0.0, 0.0, log2(max(input.viewDepth, 0.0001)), coverage);
}

technique OutlineGeometry < string MMDPass = "edge"; > {
    pass WriteOutline < string Script = "Draw=Geometry;"; > {
        AlphaBlendEnable = FALSE; AlphaTestEnable = FALSE;
        ZEnable = TRUE; ZWriteEnable = TRUE; ZFunc = LESS;
        CullMode = CW; FillMode = SOLID; StencilEnable = FALSE;
        SRGBWriteEnable = FALSE; ColorWriteEnable = 15;
        VertexShader = compile vs_3_0 ProjectOutline();
        PixelShader = compile ps_3_0 OutlineDepth();
    }
}
#else
technique NoEdge < string MMDPass = "edge"; > {}
#endif
technique NoShadow < string MMDPass = "shadow"; > {}
technique NoZPlot < string MMDPass = "zplot"; > {}
