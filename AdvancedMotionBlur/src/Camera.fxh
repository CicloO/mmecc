float3 CameraForward()
{
    return float3(View[0][2], View[1][2], View[2][2]);
}

float3 CameraUp()
{
    return float3(View[0][1], View[1][1], View[2][1]);
}

// X: timeline interval, Y: exposure, Z: screen speed, W: cut flag.
float4 CurrentCameraAnalysis()
{
    return tex2Dlod(AnalysisSampler, float4(0.5, 0.5, 0.0, 0.0));
}

float CameraBlurInterval(float4 analysis)
{
#if MB_KEEP_OBJECT_MOTION_ON_CUT
    return analysis.x;
#else
    return analysis.w > 0.5 ? 0.0 : analysis.x;
#endif
}

float4 StoreCamera(float2 quadUV : TEXCOORD0) : COLOR0
{
    int slot = (int)(quadUV.x * 8.0 + 0.5);
    if (slot < 4) {
        return ViewProjection[slot];
    }
    if (slot == 4) {
        return float4(Timeline, ScreenSize, CameraHistoryTag);
    }
    if (slot == 5) {
        return float4(CameraForward(), Projection[1][1]);
    }
    if (slot == 6) {
        return float4(CameraUp(), Projection[2][3]);
    }
    return float4(CurrentCameraAnalysis().z, 0.0, 0.0, 0.0);
}

float4 PreviousCamera(float slot)
{
    return tex2Dlod(CameraSampler, float4((slot + 0.5) / 8.0, 0.5, 0.0, 0.0));
}

float4x4 PreviousViewProjection()
{
    return float4x4(PreviousCamera(0.0), PreviousCamera(1.0), PreviousCamera(2.0), PreviousCamera(3.0));
}

float4 ReprojectToPrevious(float2 ndc, float logDepth, float4x4 previous)
{
    float depth = exp2(logDepth);
    float4 projectionZW = mul(float4(0.0, 0.0, depth, 1.0), Projection);
    float4 currentClip = float4(ndc * projectionZW.w, projectionZW.zw);
    return mul(mul(currentClip, InverseViewProjection), previous);
}

float2 CameraDisplacement(float2 uv, float logDepth)
{
    float2 ndc = (uv * 2.0 - 1.0) * float2(1.0, -1.0);
    float4 oldClip = ReprojectToPrevious(ndc, logDepth, PreviousViewProjection());
    if (oldClip.w < 0.0001) {
        return 0.0;
    }
    return (ndc - oldClip.xy / oldClip.w) * float2(0.5, -0.5) * ScreenSize;
}

static const float2 CameraProbes[5] = {
    float2(0.25, 0.25), float2(0.75, 0.25), float2(0.5, 0.5),
    float2(0.25, 0.75), float2(0.75, 0.75),
};

float MedianScreenDisplacement()
{
    float4x4 previous = PreviousViewProjection();
    float samples[5];
    int valid = 0;
    [unroll]
    for (int i = 0; i < 5; ++i) {
        float2 uv = CameraProbes[i];
        float4 geometry = tex2Dlod(GeometrySampler, float4(uv, 0.0, 0.0));
        float2 ndc = (uv * 2.0 - 1.0) * float2(1.0, -1.0);
        float4 oldClip = ReprojectToPrevious(ndc, geometry.b, previous);
        float2 displacement = (ndc - oldClip.xy / max(oldClip.w, 0.0001))
            * (0.5 * float2(ScreenSize.x / ScreenSize.y, 1.0));
        // Behind the old camera counts as a large change. Empty probes sort last.
        float distance = oldClip.w <= 0.0001 ? 4.0 : min(length(displacement), 4.0);
        samples[i] = geometry.a > 0.0 ? distance : 8.0;
        valid += geometry.a > 0.0 ? 1 : 0;
    }
    [unroll]
    for (int left = 0; left < 3; ++left) {
        [unroll]
        for (int right = left + 1; right < 5; ++right) {
            float smaller = min(samples[left], samples[right]);
            samples[right] = max(samples[left], samples[right]);
            samples[left] = smaller;
        }
    }
    if (valid == 0) {
        return -1.0;
    }
    return valid == 5 ? samples[2] : (valid >= 3 ? samples[1] : samples[0]);
}

float4 AnalyzeCameraFrame() : COLOR0
{
    float4 timing = PreviousCamera(4.0);
    float dt = Timeline - timing.x;
    if (timing.w != CameraHistoryTag || any(abs(timing.yz - ScreenSize) > 0.5)
        || !(dt > MB_MIN_FRAME_GAP && dt <= MB_MAX_FRAME_GAP)) {
        return 0.0;
    }

    float4 previousForward = PreviousCamera(5.0);
    float4 previousUp = PreviousCamera(6.0);
    bool cut = dot(previousForward.xyz, CameraForward()) < MB_CUT_ANGLE_COS
        || dot(previousUp.xyz, CameraUp()) < MB_CUT_ANGLE_COS
        || abs(previousUp.w - Projection[2][3]) > 0.5;

    float displacement = MB_CUT_SCREEN_HEIGHT > 0.0 ? MedianScreenDisplacement() : -1.0;
    float speed = max(displacement, 0.0) / dt;
    if (displacement >= 0.0) {
        float oldSpeed = PreviousCamera(7.0).x;
        cut = cut || (displacement > MB_CUT_SCREEN_HEIGHT
            && speed > max(oldSpeed, 0.15) * max(MB_CUT_SPEED_RATIO, 1.0));
    } else {
        float zoomRatio = Projection[1][1] / max(previousForward.w, 0.0001);
        cut = cut || zoomRatio < 0.75 || zoomRatio > 1.33;
    }
    if (ControllerWeight(ControlKeepCamera) >= 0.5) {
        cut = false;
    }
    if (ControllerWeight(ControlForceCut) >= 0.5) {
        cut = true;
    }
    // A cut is not part of the next shot's velocity history.
    return float4(dt, ExposureScale(), cut ? 0.0 : speed, cut ? 1.0 : 0.0);
}
