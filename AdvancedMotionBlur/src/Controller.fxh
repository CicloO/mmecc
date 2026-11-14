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
MB_MORPH_WEIGHT(ControlCameraOff, "Camera Off")
MB_MORPH_WEIGHT(ControlJitterOff, "Jitter Off")
MB_MORPH_WEIGHT(ControlCameraUp, "Camera +")
MB_MORPH_WEIGHT(ControlCameraDown, "Camera -")

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

// Camera share of the motion: 0..2. "Camera Off" at 0.5 or more removes it.
float CameraMotionScale()
{
    if (ControllerWeight(ControlCameraOff) >= 0.5) {
        return 0.0;
    }
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

float MotionShutter()
{
    float base = saturate(MB_SHUTTER_ANGLE / 360.0);
    return saturate(base + (1.0 - base) * ControllerWeight(ControlShutterUp)
        - base * ControllerWeight(ControlShutterDown));
}
