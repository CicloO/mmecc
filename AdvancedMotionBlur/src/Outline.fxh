#ifndef MB_OUTLINE_SEARCH
#define MB_OUTLINE_SEARCH 3
#endif
#ifndef MB_OUTLINE_FRINGE
#define MB_OUTLINE_FRINGE 1
#endif

bool IsOpaqueSurface(float4 geometry)
{
    return geometry.a > 0.0 && geometry.a < 2.5;
}

float SceneLuma(float2 uv)
{
    return dot(tex2Dlod(SceneSampler, float4(uv, 0.0, 0.0)).rgb, float3(0.2126, 0.7152, 0.0722));
}

// Nearest opaque surface around uv whose depth is close to refDepth, searched
// ring by ring up to `rings` pixels in 8 directions.
bool NearestSurface(float2 uv, float refDepth, int rings, inout float4 resolved, inout float2 offset)
{
    float2 texel = 1.0 / ScreenSize;
    float bestGap = 2.0 * DepthTolerance;
    bool found = false;
    [loop]
    for (int ring = 1; ring <= rings && !found; ++ring) {
        [unroll]
        for (int i = 0; i < 8; ++i) {
            float2 dir = float2(i < 3 ? -1.0 : (i < 5 ? 0.0 : 1.0),
                                (i == 0 || i == 5) ? -1.0 : ((i == 2 || i == 7) ? 1.0 : 0.0));
            if (i == 3) dir = float2(0.0, -1.0);
            if (i == 4) dir = float2(0.0, 1.0);
            float2 delta = dir * ring * texel;
            float4 candidate = tex2Dlod(GeometrySampler, float4(uv + delta, 0.0, 0.0));
            float gap = abs(candidate.b - refDepth);
            if (IsOpaqueSurface(candidate) && gap < bestGap) {
                bestGap = gap;
                resolved = candidate;
                offset = delta;
                found = true;
            }
        }
    }
    return found;
}

float4 ResolveOutline(float2 uv, float4 center, out float2 offset, out float coverage)
{
    offset = 0.0;
    coverage = center.a;
    float4 resolved = center;
    if (IsOrdinaryTranslucent(center.a) || IsAdditive(center.a)) {
        return resolved;
    }
    float2 texel = 1.0 / ScreenSize;
    if (center.a > 3.5) {
        // An expanded vertex and its unexpanded history cannot be subtracted.
        // Use nearby surface velocity, with native outline depth as a camera fallback.
        // Outlines are often 2-3 px wide, so the outer pixels have no surface
        // among their direct neighbours; search a few rings outwards.
        resolved.a = 1.0;
        NearestSurface(uv, center.b, MB_OUTLINE_SEARCH, resolved, offset);
        return resolved;
    }
    bool translucent = center.a > 2.5;
#if !MB_OUTLINE_FRINGE
    if (translucent) {
        return resolved;
    }
#endif

#if MB_OUTLINE_FRINGE
    // MMD antialiases the main image but the auxiliary buffer is not, so the
    // outline's soft fringe lands on pixels recorded as the background behind
    // it, or as a translucent layer along the silhouette. Those pixels would
    // stay put as a dashed dark line while the outline moves. Treat a pixel
    // next to a native outline as part of it: background or farther pixels,
    // and translucent pixels at about the outline's depth.
    // Find the first qualifying outline neighbour, then search once: inlining
    // the ring search per neighbour made MME's compiler several times slower.
    float outlineDepth = 0.0;
    bool touchesOutline = false;
    [unroll]
    for (int n = 0; n < 4; ++n) {
        float2 step = (n < 2 ? float2(1.0, 0.0) : float2(0.0, 1.0)) * ((n % 2 == 0) ? 1.0 : -1.0);
        float4 neighbor = tex2Dlod(GeometrySampler, float4(uv + step * texel, 0.0, 0.0));
        bool behind = center.a <= 0.0 || center.b - neighbor.b > DepthTolerance;
        bool sameLayer = abs(center.b - neighbor.b) <= 2.0 * DepthTolerance;
        if (!touchesOutline && neighbor.a > 3.5 && !IsAdditive(neighbor.a) &&
            (translucent ? (behind || sameLayer) : behind)) {
            touchesOutline = true;
            outlineDepth = neighbor.b;
        }
    }
    [branch]
    if (touchesOutline) {
        float4 surface = resolved;
        float2 surfaceOffset = 0.0;
        if (NearestSurface(uv, outlineDepth, MB_OUTLINE_SEARCH + 1, surface, surfaceOffset)) {
            resolved = surface;
            offset = surfaceOffset;
            coverage = 4.0;
        }
    }
    if (coverage > 3.5 || translucent) {
        return resolved;
    }
#endif

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
            bool sameBack = center.a <= 0.0 ? !HasGeometryCoverage(back.a)
                : IsOpaqueSurface(back) && abs(back.b - center.b) <= DepthTolerance;
            bool closer = center.a <= 0.0 || center.b - front.b > DepthTolerance;
            if (IsOpaqueSurface(front) && sameBack && closer && (coverage < 3.5 || front.b < resolved.b)) {
                resolved = front;
                offset = useA ? -step : step;
                coverage = 4.0;
            }
        }
    }
    return resolved;
}
