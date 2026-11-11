// Reload the effect after editing. Distances are in output pixels.
#define MB_QUALITY 1               // 0: 8 taps; 1: 16 taps; 2: 24 taps
#define MB_SHUTTER_ANGLE 180.0     // Relative to a 30 fps frame, at any export rate
#define MB_MOTION_SCALE 1.0
#define MB_MAX_STREAK 48.0         // Full streak, half on either side
#define MB_DEPTH_TOLERANCE 0.045   // Log2 depth tolerance; roughly 3% before soft falloff
#define MB_CUT_ANGLE_COS 0.7660444 // 40 degree orientation change
#define MB_MAX_FRAME_GAP 0.0501    // Seconds
#define MB_CLEAR_RGBA 1.0, 1.0, 1.0, 0.0
#define MB_DEBUG 0                 // 0: result; 1: source; 2: motion; 3: depth; 4: coverage
#define MB_EXTEND_FOREGROUND 1     // 0: use the P0 within-surface blur
#define MB_OUTLINE_MOTION 1        // 0: disable outline coverage and velocity repair
#define MB_AUTO_MODEL_MOTION 1     // PMD/PMX use vertex history by default
#define MB_HISTORY_SIZE 512        // Square vertex atlas used by MotionGeometry.fx
