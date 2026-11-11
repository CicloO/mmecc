texture MotionField : RENDERCOLORTARGET < string Format = "A16B16G16R16F"; >;

// Nominally 32 output pixels per tile. Use the actual raster size in the passes
// so odd viewport dimensions and MME's ratio rounding still cover all pixels.
#define MB_TILE_RATIO float2 ViewPortRatio = {0.03125, 0.03125};
texture TileMax : RENDERCOLORTARGET < MB_TILE_RATIO string Format = "A16B16G16R16F"; >;
texture NeighborMax : RENDERCOLORTARGET < MB_TILE_RATIO string Format = "A16B16G16R16F"; >;
texture TileDepth : RENDERDEPTHSTENCILTARGET < MB_TILE_RATIO >;
#undef MB_TILE_RATIO

sampler2D MotionSampler = sampler_state { Texture = <MotionField>; MB_POINT_FILTER };
sampler2D TileSampler = sampler_state { Texture = <TileMax>; MB_POINT_FILTER };
sampler2D NeighborSampler = sampler_state { Texture = <NeighborMax>; MB_POINT_FILTER };

#if MB_OUTLINE_MOTION
#include "Outline.fxh"
#endif

float4 BuildMotionField(float2 quadUV : TEXCOORD0) : COLOR0
{
    float2 uv = quadUV + 0.5 / ScreenSize;
    float4 geometry = tex2Dlod(GeometrySampler, float4(uv, 0.0, 0.0));
    float dt = CameraInterval();
    float exposure = ExposureScale();
    float2 offset = 0.0;
    float coverage = geometry.a;
#if MB_OUTLINE_MOTION
    [branch]
    if (dt > 0.0 && exposure > 0.0) {
        geometry = ResolveOutline(uv, geometry, offset, coverage);
    }
#endif
    float2 streak = ExposureStreak(quadUV + offset, geometry, dt, exposure);
    return float4(streak, geometry.b, coverage);
}

float2 TileRasterSize(float2 quadUV)
{
    return floor(rcp(float2(ddx(quadUV.x), ddy(quadUV.y))) + 0.5);
}

// RG selects a search direction. B independently stores the nearest depth
// among moving samples so the gather can skip pixels that already occlude them.
void AccumulateTile(inout float4 best, float3 candidate, float lengthSquared)
{
    if (lengthSquared >= MinStreak * MinStreak) {
        best.b = min(best.b, candidate.b);
        if (lengthSquared > best.a) {
            best.rg = candidate.rg;
            best.a = lengthSquared;
        }
    }
}

float4 BuildTileMax(float2 quadUV : TEXCOORD0) : COLOR0
{
    float2 rasterSize = TileRasterSize(quadUV);
    float4 best = float4(0.0, 0.0, 128.0, 0.0);
    float2 tile = floor(quadUV * rasterSize + 0.5);
    float2 tileSpan = ScreenSize / rasterSize;
    int2 first = (int2)floor(tile * tileSpan + 0.5);
    int2 end = min((int2)ScreenSize, (int2)floor((tile + 1.0) * tileSpan + 0.5));
    [loop]
    for (int y = first.y; y < end.y; ++y) {
        [loop]
        for (int x = first.x; x < end.x; ++x) {
            float2 uv = (float2(x, y) + 0.5) / ScreenSize;
            float3 sampleMotion = tex2Dlod(MotionSampler, float4(uv, 0.0, 0.0)).rgb;
            AccumulateTile(best, sampleMotion, dot(sampleMotion.rg, sampleMotion.rg));
        }
    }
    return float4(best.rgb, 0.0);
}

float4 BuildNeighborMax(float2 quadUV : TEXCOORD0) : COLOR0
{
    float2 rasterSize = TileRasterSize(quadUV);
    float4 best = float4(0.0, 0.0, 128.0, 0.0);
    float2 tile = floor(quadUV * rasterSize + 0.5);
    float2 tileSpan = ScreenSize / rasterSize;
    float2 radius = ceil((0.5 * MotionStreakLimit() + 1.0) / tileSpan);
    int2 first = (int2)max(0.0, tile - radius);
    int2 last = (int2)min(rasterSize - 1.0, tile + radius);
    [loop]
    for (int y = first.y; y <= last.y; ++y) {
        [loop]
        for (int x = first.x; x <= last.x; ++x) {
            float2 sourceTile = float2(x, y);
            float2 uv = (sourceTile + 0.5) / rasterSize;
            float3 sampleMotion = tex2Dlod(TileSampler, float4(uv, 0.0, 0.0)).rgb;
            float lengthSquared = dot(sampleMotion.rg, sampleMotion.rg);
            float2 gap = max(0.0, (abs(sourceTile - tile) - 1.0) * tileSpan - 1.0);
            float reach = 0.5 * sqrt(lengthSquared) + 1.0;
            if (dot(gap, gap) <= reach * reach) {
                AccumulateTile(best, sampleMotion, lengthSquared);
            }
        }
    }
    return float4(best.rgb, 0.0);
}

float3 ExtendForeground(float2 uv, float3 background, float4 center)
{
    if (center.a > 2.5 && center.a < 3.5) {
        return background;
    }
    float3 neighbor = tex2Dlod(NeighborSampler, float4(uv, 0.0, 0.0)).rgb;
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
        support *= 1.0 - smoothstep(0.5, 1.25, across);
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
