static const float RigidHistoryTag = 641.25;

texture CurrentRigid : RENDERCOLORTARGET <
    int Width = 8;
    int Height = 1;
    string Format = "A32B32G32R32F";
>;
texture PreviousRigid : RENDERCOLORTARGET <
    int Width = 8;
    int Height = 1;
    string Format = "A32B32G32R32F";
>;
texture RigidDepth : RENDERDEPTHSTENCILTARGET < int Width = 8; int Height = 1; >;

sampler2D CurrentRigidSampler = sampler_state { Texture = <CurrentRigid>; MB_HISTORY_FILTER };
sampler2D PreviousRigidSampler = sampler_state { Texture = <PreviousRigid>; MB_HISTORY_FILTER };

float4 PreviousRigidSlot(float index)
{
    return tex2Dlod(PreviousRigidSampler, float4((index + 0.5) / 8.0, 0.5, 0.0, 0.0));
}

float4 RigidPreviousWorld(float4 position)
{
    float4 timing = PreviousRigidSlot(4.0);
    float4 cameraTiming = HistoryCameraSlot(4.0);
    float dt = Timeline - timing.x;
    [branch]
    if (timing.w != RigidHistoryTag || cameraTiming.w != CameraHistoryTag ||
        !(dt > MB_MIN_FRAME_GAP && dt <= MB_MAX_FRAME_GAP) ||
        abs(cameraTiming.x - timing.x) > MB_MIN_FRAME_GAP ||
        any(abs(cameraTiming.yz - TargetSize) > 0.5)) {
        return 0.0;
    }

    float4x4 previous = float4x4(PreviousRigidSlot(0.0), PreviousRigidSlot(1.0),
                                 PreviousRigidSlot(2.0), PreviousRigidSlot(3.0));
    if (all(previous[0] == ObjectToWorld[0]) && all(previous[1] == ObjectToWorld[1]) &&
        all(previous[2] == ObjectToWorld[2]) && all(previous[3] == ObjectToWorld[3])) {
        // Static stages use the original per-pixel camera reprojection.
        return 0.0;
    }
    float4 world = mul(position, previous);
    float3 shift = mul(position, ObjectToWorld).xyz - world.xyz;
    return HistoryTeleported(shift) ? 0.0 : world;
}

float4 RecordRigid(float2 quadUV : TEXCOORD0) : COLOR0
{
    int slot = (int)(quadUV.x * 8.0 + 0.5);
    if (slot < 4) {
        return ObjectToWorld[slot];
    }
    if (slot == 4) {
        return float4(Timeline, 0.0, 0.0, RigidHistoryTag);
    }
    return 0.0;
}

float4 CopyRigid(float2 quadUV : TEXCOORD0) : COLOR0
{
    float2 uv = quadUV + float2(0.5 / 8.0, 0.5);
    return tex2Dlod(CurrentRigidSampler, float4(uv, 0.0, 0.0));
}
