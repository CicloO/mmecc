bool IsOpaqueSurface(float4 geometry)
{
    return geometry.a >= 0.5 && geometry.a < 2.5;
}

float SceneLuma(float2 uv)
{
    return dot(tex2Dlod(SceneSampler, float4(uv, 0.0, 0.0)).rgb, float3(0.2126, 0.7152, 0.0722));
}

float4 ResolveOutline(float2 uv, float4 center, out float2 offset, out float coverage)
{
    offset = 0.0;
    coverage = center.a;
    float4 resolved = center;
    float2 texel = 1.0 / ScreenSize;
    if (center.a > 3.5) {
        // An expanded vertex and its unexpanded history cannot be subtracted.
        // Use nearby surface velocity, with native outline depth as a camera fallback.
        resolved.a = 1.0;
        float bestGap = 2.0 * DepthTolerance;
        [unroll]
        for (int i = 0; i < 4; ++i) {
            float2 step = (i < 2 ? float2(1.0, 0.0) : float2(0.0, 1.0)) * ((i % 2 == 0) ? 1.0 : -1.0);
            float2 delta = step * texel;
            float4 candidate = tex2Dlod(GeometrySampler, float4(uv + delta, 0.0, 0.0));
            float gap = abs(candidate.b - center.b);
            if (IsOpaqueSurface(candidate) && gap < bestGap) {
                bestGap = gap;
                resolved = candidate;
                offset = delta;
            }
        }
        return resolved;
    }
    if (center.a > 2.5) {
        return resolved;
    }

    // Screen-space outlines can lie on a background pixel in the auxiliary pass.
    // Require a one-pixel dark line between a closer surface and the center's layer.
    float darkness = SceneLuma(uv) + 0.055;
    [unroll]
    for (int axis = 0; axis < 2; ++axis) {
        float2 step = (axis == 0 ? float2(1.0, 0.0) : float2(0.0, 1.0)) * texel;
        float2 aUV = uv - step;
        float2 bUV = uv + step;
        [branch]
        if (all(aUV >= 0.0) && all(bUV < 1.0) && min(SceneLuma(aUV), SceneLuma(bUV)) > darkness) {
            float4 a = tex2Dlod(GeometrySampler, float4(aUV, 0.0, 0.0));
            float4 b = tex2Dlod(GeometrySampler, float4(bUV, 0.0, 0.0));
            bool useA = IsOpaqueSurface(a) && (!IsOpaqueSurface(b) || a.b < b.b);
            float4 front = useA ? a : b;
            float4 back = useA ? b : a;
            bool sameBack = center.a < 0.5 ? back.a < 0.5
                : IsOpaqueSurface(back) && abs(back.b - center.b) <= DepthTolerance;
            bool closer = center.a < 0.5 || center.b - front.b > DepthTolerance;
            if (IsOpaqueSurface(front) && sameBack && closer && (coverage < 3.5 || front.b < resolved.b)) {
                resolved = front;
                offset = useA ? -step : step;
                coverage = 4.0;
            }
        }
    }
    return resolved;
}
