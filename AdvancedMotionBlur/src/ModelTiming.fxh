// A=0 remains empty. The positive range below 0.5 carries the model
// interval in GeometryData; A=2 still accepts already-synchronized history.
static const float ModelIntervalScale = 0.25 / max(MB_MAX_FRAME_GAP, 0.0001);

float EncodeModelInterval(float interval)
{
    return interval * ModelIntervalScale;
}

bool HasModelMotion(float coverage, float cameraInterval)
{
    if (coverage > 0.0 && coverage < 0.5) {
        float expected = EncodeModelInterval(cameraInterval);
        // An RGBA16F target can round or truncate the encoded interval.
        float tolerance = max(expected / 1024.0, 1.0 / 16777216.0);
        return cameraInterval > 0.0 && abs(coverage - expected) <= tolerance;
    }
    return coverage > 1.5 && coverage < 2.5;
}
