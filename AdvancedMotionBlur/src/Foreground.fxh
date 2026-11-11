texture MotionField : RENDERCOLORTARGET < string Format = "A16B16G16R16F"; >;

#ifndef MB_TRAIL_SPREAD
#define MB_TRAIL_SPREAD 0.35
#endif

// Nominally 32 output pixels per tile. Use the actual raster size in the passes
// so odd viewport dimensions and MME's ratio rounding still cover all pixels.
#define MB_TILE_RATIO float2 ViewPortRatio = {0.03125, 0.03125};
texture TileMax : RENDERCOLORTARGET < MB_TILE_RATIO string Format = "A16B16G16R16F"; >;
texture NeighborMax : RENDERCOLORTARGET < MB_TILE_RATIO string Format = "A16B16G16R16F"; >;
#if MB_LAYERED_TRAIL
texture TileAlternate : RENDERCOLORTARGET < MB_TILE_RATIO string Format = "A16B16G16R16F"; >;
texture NeighborAlternate : RENDERCOLORTARGET < MB_TILE_RATIO string Format = "A16B16G16R16F"; >;
#endif
texture TileDepth : RENDERDEPTHSTENCILTARGET < MB_TILE_RATIO >;
#undef MB_TILE_RATIO

sampler2D MotionSampler = sampler_state { Texture = <MotionField>; MB_POINT_FILTER };
sampler2D TileSampler = sampler_state { Texture = <TileMax>; MB_POINT_FILTER };
sampler2D NeighborSampler = sampler_state { Texture = <NeighborMax>; MB_POINT_FILTER };
#if MB_LAYERED_TRAIL
sampler2D TileAlternateSampler = sampler_state { Texture = <TileAlternate>; MB_POINT_FILTER };
sampler2D NeighborAlternateSampler = sampler_state { Texture = <NeighborAlternate>; MB_POINT_FILTER };
#endif

#if MB_OUTLINE_MOTION
#include "Outline.fxh"
#endif

float4 BuildMotionField(float2 quadUV : TEXCOORD0) : COLOR0
{
    float2 uv = quadUV + 0.5 / ScreenSize;
    float4 geometry = tex2Dlod(GeometrySampler, float4(uv, 0.0, 0.0));
    float4 camera = CurrentCameraAnalysis();
    float dt = CameraBlurInterval(camera);
    float exposure = camera.y;
    float2 offset = 0.0;
    float coverage = geometry.a;
#if MB_OUTLINE_MOTION
    [branch]
    if (dt > 0.0 && exposure > 0.0) {
        geometry = ResolveOutline(uv, geometry, offset, coverage);
    }
#endif
    float2 streak = ExposureStreak(quadUV + offset, geometry, camera);
    return float4(streak, geometry.b, coverage);
}

// Upper bounds for the reduction loops. A tile covers about 32 px; allow for
// MME's ratio rounding. The neighbour search reaches half the largest streak
// (MB_MAX_STREAK with Streak + at 1) plus 1 px, in tiles of at least 24 px.
#define MaxTileSpan 40
#define MaxNeighborSpan (2 * (int)ceil((max(MB_MAX_STREAK, 0.0) + 1.0) / 24.0) + 1)

float2 TileRasterSize(float2 quadUV)
{
    return floor(rcp(float2(ddx(quadUV.x), ddy(quadUV.y))) + 0.5);
}

struct TileReduction {
    float4 primary;
    float nearest;
#if MB_LAYERED_TRAIL
    float4 alternate;
#endif
};

struct TileOutput {
    float4 primary : COLOR0;
#if MB_LAYERED_TRAIL
    float4 alternate : COLOR1;
#endif
};

TileOutput FinishTile(TileReduction reduction)
{
    TileOutput result;
#if MB_LAYERED_TRAIL
    result.primary = float4(reduction.primary.rg, reduction.nearest, reduction.primary.b);
    result.alternate = float4(reduction.alternate.rg, reduction.alternate.b, reduction.alternate.b);
#else
    result.primary = float4(reduction.primary.rg, reduction.nearest, 0.0);
#endif
    return result;
}

bool FrameHasExposure()
{
    float4 camera = CurrentCameraAnalysis();
    return CameraBlurInterval(camera) > 0.0 && camera.y > 0.0;
}

// RG carries a search direction. Track its depth and the nearest depth
// separately so a layer change cannot borrow the wrong motion.
void AccumulateTile(inout TileReduction best, float3 candidate, float nearest, float lengthSquared)
{
    if (lengthSquared >= MinStreak * MinStreak) {
        best.nearest = min(best.nearest, nearest);
        float4 ranked = float4(candidate, lengthSquared);
        if (lengthSquared > best.primary.a) {
#if MB_LAYERED_TRAIL
            if (best.primary.a > 0.0 && abs(best.primary.b - candidate.b) > 2.0 * DepthTolerance) {
                best.alternate = best.primary;
            } else if (abs(best.alternate.b - candidate.b) <= 2.0 * DepthTolerance) {
                best.alternate = 0.0;
            }
#endif
            best.primary = ranked;
        }
#if MB_LAYERED_TRAIL
        else if (lengthSquared > best.alternate.a && abs(best.primary.b - candidate.b) > 2.0 * DepthTolerance) {
            best.alternate = ranked;
        }
#endif
    }
}

TileOutput BuildTileMax(float2 quadUV : TEXCOORD0)
{
    float2 rasterSize = TileRasterSize(quadUV);
    TileReduction best = (TileReduction)0;
    best.nearest = 128.0;
    [branch]
    if (!FrameHasExposure()) {
        return FinishTile(best);
    }
    float2 tile = floor(quadUV * rasterSize + 0.5);
    float2 tileSpan = ScreenSize / rasterSize;
    float2 first = floor(tile * tileSpan + 0.5);
    float2 count = min(ScreenSize, floor((tile + 1.0) * tileSpan + 0.5)) - first;
    // Constant trip counts: d3dx9_43 (MME's compiler) otherwise simulates a
    // runtime-bounded loop for seconds while optimising.
    [loop]
    for (int j = 0; j < MaxTileSpan; ++j) {
        if (j >= count.y) break;
        [loop]
        for (int i = 0; i < MaxTileSpan; ++i) {
            if (i >= count.x) break;
            float2 uv = (first + float2(i, j) + 0.5) / ScreenSize;
            float3 sampleMotion = tex2Dlod(MotionSampler, float4(uv, 0.0, 0.0)).rgb;
            AccumulateTile(best, sampleMotion, sampleMotion.b, dot(sampleMotion.rg, sampleMotion.rg));
        }
    }
    return FinishTile(best);
}

void AccumulateNeighbor(inout TileReduction best, float4 sampleMotion, float2 gap)
{
    float lengthSquared = dot(sampleMotion.rg, sampleMotion.rg);
    float reach = 0.5 * sqrt(lengthSquared) + 1.0;
    if (dot(gap, gap) <= reach * reach) {
#if MB_LAYERED_TRAIL
        AccumulateTile(best, sampleMotion.rga, sampleMotion.b, lengthSquared);
#else
        AccumulateTile(best, sampleMotion.rgb, sampleMotion.b, lengthSquared);
#endif
    }
}

TileOutput BuildNeighborMax(float2 quadUV : TEXCOORD0)
{
    float2 rasterSize = TileRasterSize(quadUV);
    TileReduction best = (TileReduction)0;
    best.nearest = 128.0;
    [branch]
    if (!FrameHasExposure()) {
        return FinishTile(best);
    }
    float2 tile = floor(quadUV * rasterSize + 0.5);
    float2 tileSpan = ScreenSize / rasterSize;
    float2 radius = ceil((0.5 * MotionStreakLimit() + 1.0) / tileSpan);
    float2 first = max(0.0, tile - radius);
    float2 count = min(rasterSize - 1.0, tile + radius) - first + 1.0;
    [loop]
    for (int j = 0; j < MaxNeighborSpan; ++j) {
        if (j >= count.y) break;
        [loop]
        for (int i = 0; i < MaxNeighborSpan; ++i) {
            if (i >= count.x) break;
            float2 sourceTile = first + float2(i, j);
            float2 uv = (sourceTile + 0.5) / rasterSize;
            float2 gap = max(0.0, (abs(sourceTile - tile) - 1.0) * tileSpan - 1.0);
            AccumulateNeighbor(best, tex2Dlod(TileSampler, float4(uv, 0.0, 0.0)), gap);
#if MB_LAYERED_TRAIL
            AccumulateNeighbor(best, tex2Dlod(TileAlternateSampler, float4(uv, 0.0, 0.0)), gap);
#endif
        }
    }
    return FinishTile(best);
}

#if MB_LAYERED_TRAIL
float3 GatherForeground(float2 uv, float3 background, float4 center, float3 neighbor,
                        float splitDepth, float depthSide)
{
#else
float3 ExtendForeground(float2 uv, float3 background, float4 center)
{
    if (center.a > 2.5 && center.a < 3.5) {
        return background;
    }
    float3 neighbor = tex2Dlod(NeighborSampler, float4(uv, 0.0, 0.0)).rgb;
#endif
    bool hasDepth = center.a >= 0.5;
    float streakLength = length(neighbor.rg);
    if (streakLength < MinStreak || (hasDepth && center.b - neighbor.b <= DepthTolerance)) {
        return background;
    }

    float2 direction = neighbor.rg / streakLength;
    float reach = 0.5 * streakLength + 0.75;
    int taps = (int)min(64.0, ceil(2.0 * reach));
    float spacing = 2.0 * reach / taps;
    float2 centerPixel = uv * ScreenSize;
    float4 exposure = 0.0;
    [loop]
    for (int tap = 0; tap < taps; ++tap) {
        float offset = (tap + 0.5) * spacing - reach;
        float2 samplePixel = floor(centerPixel + offset * direction) + 0.5;
        if (any(samplePixel < 0.0) || any(samplePixel >= ScreenSize)) {
            continue;
        }
        float2 tapUV = samplePixel / ScreenSize;
        float4 source = tex2Dlod(MotionSampler, float4(tapUV, 0.0, 0.0));
#if MB_LAYERED_TRAIL
        if (depthSide != 0.0 && (source.b < splitDepth) != (depthSide < 0.0)) {
            continue;
        }
#endif
        float sourceLength = length(source.rg);
        if (sourceLength < MinStreak || (hasDepth && center.b - source.b <= DepthTolerance)) {
            continue;
        }

        // Check the source pixel's own motion, even when NeighborMax chose a
        // different vector. A background tap cannot paint across a nearer edge.
        float2 axis = source.rg / sourceLength;
        float2 delta = samplePixel - centerPixel;
        float along = abs(dot(delta, axis));
        float across = abs(dot(delta, float2(-axis.y, axis.x)));
        float halfLength = 0.5 * sourceLength;
        float support = 1.0 - smoothstep(max(0.0, halfLength - 0.75), halfLength + 0.75, along);
        // The ray follows the tile's dominant direction, which differs a little
        // from each source's own. A fixed ~1 px width only lets aligned pixels
        // through and breaks thin outlines into dots, so widen it with distance.
        float spread = MB_TRAIL_SPREAD * along;
        support *= 1.0 - smoothstep(0.5 + spread, 1.25 + spread, across);
        if (hasDepth) {
            support *= smoothstep(DepthTolerance, 2.0 * DepthTolerance, center.b - source.b);
        }
        if (support > 0.0) {
            float4 sourceColor = tex2Dlod(SceneSampler, float4(tapUV, 0.0, 0.0));
            float alpha = source.a > 3.5 ? 1.0 : sourceColor.a;
            float weight = support * alpha * spacing / max(1.0, sourceLength);
            exposure += float4(sourceColor.rgb, 1.0) * weight;
        }
    }
    float3 foreground = exposure.rgb / max(exposure.a, 0.0001);
    return lerp(background, foreground, saturate(exposure.a));
}

#if MB_LAYERED_TRAIL
float3 ExtendForeground(float2 uv, float3 background, float4 center)
{
    if (center.a > 2.5 && center.a < 3.5) {
        return background;
    }
    float4 primary = tex2Dlod(NeighborSampler, float4(uv, 0.0, 0.0));
    float4 alternate = tex2Dlod(NeighborAlternateSampler, float4(uv, 0.0, 0.0));
    bool twoLayers = dot(alternate.rg, alternate.rg) >= MinStreak * MinStreak;
    bool primaryIsFar = primary.a > alternate.a;
    float3 farLayer = primaryIsFar ? primary.rgb : alternate.rgb;
    float3 nearLayer = primaryIsFar ? alternate.rgb : primary.rgb;
    float splitDepth = 0.5 * (primary.a + alternate.a);
    [loop]
    for (int layer = 0; layer < 2; ++layer) {
        if (layer > 0 && !twoLayers) break;
        float3 candidate = twoLayers ? (layer == 0 ? farLayer : nearLayer) : primary.rgb;
        float depthSide = twoLayers ? (layer == 0 ? 1.0 : -1.0) : 0.0;
        background = GatherForeground(uv, background, center, candidate, splitDepth, depthSide);
    }
    return background;
}
#endif
