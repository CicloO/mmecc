// Reload the effect after editing. Distances are in output pixels.
#define MB_QUALITY 1               // 0: 8 taps; 1: 16 taps; 2: 24 taps
#define MB_SHUTTER_ANGLE 180.0
#define MB_MOTION_SCALE 1.0
#define MB_OUTPUT_FPS 30.0         // Set to the AVI export frame rate
#define MB_MAX_STREAK 48.0         // Full streak, half on either side
#define MB_DEPTH_TOLERANCE 0.045   // Log2 depth tolerance; roughly 3% before soft falloff
#define MB_CUT_ANGLE_COS 0.7660444 // 40 degree orientation change
#define MB_MAX_FRAME_GAP 0.0501    // Seconds
#define MB_CLEAR_RGBA 1.0, 1.0, 1.0, 0.0
#define MB_DEBUG 0                 // 0: result; 1: source; 2: motion; 3: depth; 4: coverage
#define MB_HISTORY_SIZE 512        // Square vertex atlas used by MotionGeometry.fx
