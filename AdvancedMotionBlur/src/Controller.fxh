#define MB_CONTROLLER_NAME "AdvancedMotionBlurController.pmx"

bool ControllerLoaded : CONTROLOBJECT < string name = MB_CONTROLLER_NAME; > = false;

#define MB_MORPH_WEIGHT(variable, label) \
    float variable : CONTROLOBJECT < string name = MB_CONTROLLER_NAME; string item = label; > = 0.0;

MB_MORPH_WEIGHT(ControlStrengthUp, "Strength +")
MB_MORPH_WEIGHT(ControlStrengthDown, "Strength -")
MB_MORPH_WEIGHT(ControlShutterUp, "Shutter +")
MB_MORPH_WEIGHT(ControlShutterDown, "Shutter -")
MB_MORPH_WEIGHT(ControlStreakUp, "Streak +")
MB_MORPH_WEIGHT(ControlStreakDown, "Streak -")
MB_MORPH_WEIGHT(ControlThreshold, "Threshold")
MB_MORPH_WEIGHT(ControlForceCut, "Force Cut")
MB_MORPH_WEIGHT(ControlKeepCamera, "Keep Camera")
MB_MORPH_WEIGHT(ControlCameraDown, "Camera -")
MB_MORPH_WEIGHT(ControlJitterOff, "Jitter Off")
MB_MORPH_WEIGHT(ControlCameraUp, "Camera +")
MB_MORPH_WEIGHT(ControlGaussian, "Gaussian")

#undef MB_MORPH_WEIGHT

float ControllerWeight(float value)
{
    return ControllerLoaded ? saturate(value) : 0.0;
}

float MotionStrength()
{
    return max(MB_MOTION_SCALE, 0.0) *
        (1.0 + ControllerWeight(ControlStrengthUp) - ControllerWeight(ControlStrengthDown));
}

// Camera share of the motion: 0..2. "Camera -" at 1 removes it.
float CameraMotionScale()
{
    return max(0.0, 1.0 + ControllerWeight(ControlCameraUp) - ControllerWeight(ControlCameraDown));
}

float MotionStreakLimit()
{
    return StreakPixelScale() * max(MB_MAX_STREAK, 0.0) *
        (1.0 + ControllerWeight(ControlStreakUp) - ControllerWeight(ControlStreakDown));
}

// Threshold adds up to 16 reference pixels on top of the setting.
static const float ThresholdMorphRange = 16.0;

float MotionSpeedThreshold()
{
    return StreakPixelScale() * (max(MB_SPEED_THRESHOLD, 0.0)
        + ThresholdMorphRange * ControllerWeight(ControlThreshold));
}

// 0: every moment of the exposure counts the same (box shutter, hard streak
// ends). 1: Gaussian weighting along the streak like MotionBlur3L, soft ends.
#ifndef MB_STREAK_SOFTNESS
#define MB_STREAK_SOFTNESS 0.0
#endif

float StreakSoftness()
{
    return saturate(MB_STREAK_SOFTNESS + ControllerWeight(ControlGaussian));
}

// Weight of a sample at `position` along the streak: 0 at its centre, 0.5 at
// either end. The Gaussian falls to exp(-2) at the ends and is scaled so the
// whole streak still adds up to one exposure.
float StreakProfile(float position, float softness)
{
    return lerp(1.0, exp(-8.0 * position * position) / 0.598, softness);
}

float MotionShutter()
{
    float base = saturate(MB_SHUTTER_ANGLE / 360.0);
    return saturate(base + (1.0 - base) * ControllerWeight(ControlShutterUp)
        - base * ControllerWeight(ControlShutterDown));
}
