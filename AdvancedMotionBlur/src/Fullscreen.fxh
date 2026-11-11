struct ScreenVertex {
    float4 position : POSITION;
    float2 uv : TEXCOORD0;
};

ScreenVertex ScreenQuad(float4 position : POSITION, float2 uv : TEXCOORD0)
{
    ScreenVertex output;
    output.position = position;
    output.uv = uv;
    return output;
}
