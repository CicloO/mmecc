texture MotionField : RENDERCOLORTARGET < string Format = "A16B16G16R16F"; >;

#ifndef MB_TRAIL_SPREAD
#define MB_TRAIL_SPREAD 0.35
#endif

// Nominally 32 output pixels per tile. Use the actual raster size in the passes
// so odd viewport dimensions and MME's ratio rounding still cover all pixels.
#define MB_TILE_RATIO float2 ViewPortRatio = {0.03125, 0.03125};
texture TileMax : RENDERCOLORTARGET < MB_TILE_RATIO string Format = "A16B16G16R16F"; >;
texture NeighborMax : RENDERCOLORTARGET < MB_TILE_RATIO string Format = "A16B16G16R16F"; >;
#define MB_TILE_ROW_RATIO float2 ViewPortRatio = {0.03125, 1.0};
texture TileRows : RENDERCOLORTARGET < MB_TILE_ROW_RATIO string Format = "A16B16G16R16F"; >;
texture TileRowsDepth : RENDERDEPTHSTENCILTARGET < MB_TILE_ROW_RATIO >;
#undef MB_TILE_ROW_RATIO
texture TileDepth : RENDERDEPTHSTENCILTARGET < MB_TILE_RATIO >;
#undef MB_TILE_RATIO

sampler2D MotionSampler = sampler_state { Texture = <MotionField>; MB_POINT_FILTER };
sampler2D TileSampler = sampler_state { Texture = <TileMax>; MB_POINT_FILTER };
sampler2D NeighborSampler = sampler_state { Texture = <NeighborMax>; MB_POINT_FILTER };
sampler2D TileRowsSampler = sampler_state { Texture = <TileRows>; MB_POINT_FILTER };

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
    if (coverage > 0.0 && coverage < 0.5) {
        coverage = 2.0;
    }
#if MB_TRANSLUCENT_MOTION
    if (IsOrdinaryTranslucent(coverage)) {
        coverage = TranslucentSurface;
#if MB_USE_TRAIL_ALPHA
        // An opaque capture already includes the layer behind the material.
        float alpha = tex2Dlod(SceneSampler, float4(uv, 0.0, 0.0)).a;
        if (alpha > 0.004 && alpha < 0.985) {
            coverage = TranslucentTrailSource;
        }
#endif
    }
#endif
    return float4(streak, geometry.b, coverage);
}

bool CanExtendTrail(float coverage)
{
    return !IsOrdinaryTranslucent(coverage) || coverage == TranslucentTrailSource;
}

// A tile covers about 32 px and can reach 63 px if the ratio rounds down to one tile.
#define MaxTileSpan 63
// ps_3_0 loops can run at most 255 iterations. Split long rows and columns
// so the search covers the entire rectangle even with a large streak limit.
static const int MaxLoopIterations = 255;

float2 TileRasterSize(float2 quadUV)
{
    return floor(rcp(float2(ddx(quadUV.x), ddy(quadUV.y))) + 0.5);
}

struct TileReduction {
    float4 primary;
    float nearest;
};


float4 FinishTile(TileReduction reduction)
{
    return float4(reduction.primary.rg, reduction.nearest, 0.0);
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
    if (lengthSquared >= MinStreak() * MinStreak()) {
        best.nearest = min(best.nearest, nearest);
        if (lengthSquared > best.primary.a) {
            best.primary = float4(candidate, lengthSquared);
        }
    }
}

float4 BuildTileRows(float2 quadUV : TEXCOORD0) : COLOR0
{
    float2 rasterSize = TileRasterSize(quadUV);
    TileReduction best = (TileReduction)0;
    best.nearest = 128.0;
    [branch]
    if (!FrameHasExposure()) {
        return FinishTile(best);
    }
    float2 tileRow = floor(quadUV * rasterSize + 0.5);
    float span = ScreenSize.x / rasterSize.x;
    float first = floor(tileRow.x * span + 0.5);
    float count = min(ScreenSize.x, floor((tileRow.x + 1.0) * span + 0.5)) - first;
    [loop]
    for (int i = 0; i < MaxTileSpan; ++i) {
        if (i >= count) break;
        float2 uv = (float2(first + i, tileRow.y) + 0.5) / ScreenSize;
        float4 motion = tex2Dlod(MotionSampler, float4(uv, 0.0, 0.0));
        if (CanExtendTrail(motion.a)) {
            float lengthSquared = dot(motion.rg, motion.rg);
            AccumulateTile(best, motion.rgb, motion.b, lengthSquared);
        }
    }
    return FinishTile(best);
}

float4 BuildTileMax(float2 quadUV : TEXCOORD0) : COLOR0
{
    float2 rasterSize = TileRasterSize(quadUV);
    TileReduction best = (TileReduction)0;
    best.nearest = 128.0;
    [branch]
    if (!FrameHasExposure()) {
        return FinishTile(best);
    }
    float2 tile = floor(quadUV * rasterSize + 0.5);
    float span = ScreenSize.y / rasterSize.y;
    float first = floor(tile.y * span + 0.5);
    float count = min(ScreenSize.y, floor((tile.y + 1.0) * span + 0.5)) - first;
    // First strongest row wins a tie, matching the row-major pixel scan.
    [loop]
    for (int j = 0; j < MaxTileSpan; ++j) {
        if (j >= count) break;
        float2 uv = (float2(tile.x, first + j) + 0.5) / float2(rasterSize.x, ScreenSize.y);
        float4 motion = tex2Dlod(TileRowsSampler, float4(uv, 0.0, 0.0));
        AccumulateTile(best, motion.rgb, motion.b, dot(motion.rg, motion.rg));
    }
    return FinishTile(best);
}


void AccumulateNeighbor(inout TileReduction best, float4 sampleMotion, float2 gap,
                        bool alternate, float primaryDepth)
{
    float lengthSquared = dot(sampleMotion.rg, sampleMotion.rg);
    float reach = 0.5 * sqrt(lengthSquared) + 1.0;
    if (dot(gap, gap) <= reach * reach) {
        AccumulateTile(best, sampleMotion.rgb, sampleMotion.b, lengthSquared);
    }
}

void ReduceNeighborRow(inout TileReduction best, float2 tile, float2 tileSpan, float2 rasterSize,
                       float2 rowStart, int width, bool alternate, float primaryDepth)
{
    // fastopt prevents d3dx9_43 from simulating the runtime loop bounds.
    [fastopt]
    for (int block = 0; block < width; block += MaxLoopIterations) {
        int end = min(block + MaxLoopIterations, width);
        [fastopt]
        for (int i = block; i < end; ++i) {
            float2 sourceTile = rowStart + float2(i, 0.0);
            float2 uv = (sourceTile + 0.5) / rasterSize;
            float2 gap = max(0.0, (abs(sourceTile - tile) - 1.0) * tileSpan - 1.0);
            AccumulateNeighbor(best, tex2Dlod(TileSampler, float4(uv, 0.0, 0.0)), gap, alternate, primaryDepth);
        }
    }
}

float4 ReduceNeighbors(float2 quadUV, bool alternate)
{
    float2 rasterSize = TileRasterSize(quadUV);
    TileReduction best = (TileReduction)0;
    best.nearest = 128.0;
    [branch]
    if (!alternate && !FrameHasExposure()) {
        return FinishTile(best);
    }
    float2 tile = floor(quadUV * rasterSize + 0.5);
    float primaryDepth = 0.0;
    float2 tileSpan = ScreenSize / rasterSize;
    float2 radius = ceil((0.5 * MotionStreakLimit() + 1.0) / tileSpan);
    float2 first = max(0.0, tile - radius);
    int2 count = (int2)(min(rasterSize - 1.0, tile + radius) - first + 1.0);
    [fastopt]
    for (int block = 0; block < count.y; block += MaxLoopIterations) {
        int end = min(block + MaxLoopIterations, count.y);
        [fastopt]
        for (int j = block; j < end; ++j) {
            ReduceNeighborRow(best, tile, tileSpan, rasterSize, first + float2(0.0, j),
                              count.x, alternate, primaryDepth);
        }
    }
    return FinishTile(best);
}

float4 BuildNeighborMax(float2 quadUV : TEXCOORD0) : COLOR0
{
    return ReduceNeighbors(quadUV, false);
}

float4 ExtendForeground(float2 uv, float4 background, float4 center)
{
    if (IsProtectedSurface(center.a)) {
        return background;
    }
    float3 neighbor = tex2Dlod(NeighborSampler, float4(uv, 0.0, 0.0)).rgb;
    bool hasDepth = center.a >= 0.5 || IsOrdinaryTranslucent(center.a);
    float streakLength = length(neighbor.rg);
    if (streakLength < MinStreak() || (hasDepth && center.b - neighbor.b <= DepthTolerance)) {
        return background;
    }

    float2 direction = neighbor.rg / streakLength;
    float reach = 0.5 * streakLength + 0.75;
    int taps = (int)min(StreakTapBudget(64.0), ceil(2.0 * reach));
    float spacing = 2.0 * reach / taps;
    float2 centerPixel = uv * ScreenSize;
    float phase = TrailTapPhase(uv);
    float4 exposure = 0.0;
    [fastopt]
    for (int tap = 0; tap < taps; ++tap) {
        float offset = (tap + phase) * spacing - reach;
        float2 samplePixel = floor(centerPixel + offset * direction) + 0.5;
        if (any(samplePixel < 0.0) || any(samplePixel >= ScreenSize)) {
            continue;
        }
        float2 tapUV = samplePixel / ScreenSize;
        float4 source = tex2Dlod(MotionSampler, float4(tapUV, 0.0, 0.0));
        if (!CanExtendTrail(source.a)) {
            continue;
        }
        float sourceLength = length(source.rg);
        if (sourceLength < MinStreak() || (hasDepth && center.b - source.b <= DepthTolerance)) {
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
#if MB_USE_TRAIL_ALPHA
            float weight = support * spacing / max(1.0, sourceLength);
            exposure += sourceColor * weight;
#else
            float alpha = source.a > 3.5 ? 1.0 : sourceColor.a;
            float weight = support * alpha * spacing / max(1.0, sourceLength);
            exposure += float4(sourceColor.rgb, 1.0) * weight;
#endif
        }
    }
#if MB_USE_TRAIL_ALPHA
    // Clamp coverage for overlapping taps and keep their average color.
    exposure /= max(1.0, exposure.a);
    return exposure + background * (1.0 - exposure.a);
#else
    float3 foreground = exposure.rgb / max(exposure.a, 0.0001);
    return float4(lerp(background.rgb, foreground, saturate(exposure.a)), background.a);
#endif
}

