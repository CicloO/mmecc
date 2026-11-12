#if MB_USE_LINEAR_LIGHT
float3 SRGBToLinear(float3 srgb)
{
    float3 low = srgb / 12.92;
    float3 high = pow((srgb + 0.055) / 1.055, 2.4);
    return lerp(low, high, step(0.04045, srgb));
}

float3 LinearToSRGB(float3 linearColor)
{
    linearColor = max(linearColor, 0.0);
    float3 low = linearColor * 12.92;
    float3 high = 1.055 * pow(linearColor, 1.0 / 2.4) - 0.055;
    return lerp(low, high, step(0.0031308, linearColor));
}
#endif

float4 DecodeTrailColor(float4 color)
{
#if MB_USE_LINEAR_LIGHT
#if MB_USE_TRAIL_ALPHA
    // Transfer functions operate on straight color, including at low alpha.
    float alpha = color.a > 0.0 ? color.a : 1.0;
    color.rgb = SRGBToLinear(color.rgb / alpha) * alpha;
#else
    color.rgb = SRGBToLinear(color.rgb);
#endif
#endif
    return color;
}

float4 EncodeTrailColor(float4 color)
{
#if MB_USE_LINEAR_LIGHT
#if MB_USE_TRAIL_ALPHA
    float alpha = color.a > 0.0 ? color.a : 1.0;
    color.rgb = LinearToSRGB(color.rgb / alpha) * alpha;
#else
    color.rgb = LinearToSRGB(color.rgb);
#endif
#endif
    return color;
}
