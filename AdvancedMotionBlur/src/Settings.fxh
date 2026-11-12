// Reload the effect after editing.
#define MB_QUALITY 1              // Tap spacing along the streak: 0: 4 px; 1: 2 px; 2: 1 px; 3: fixed 16 taps (0.2.0)
#define MB_SHUTTER_ANGLE 180.0     // Relative to a 30 fps frame, at any export rate
#define MB_MOTION_SCALE 1.3
#define MB_SCALE_STREAK_WITH_HEIGHT 1 // 1: streak limits and dead zone use 1080p reference pixels
#define MB_MAX_STREAK 64.0         // Full streak, half on either side
#define MB_SPEED_THRESHOLD 3.0     // Length removed from the streak; slow parts stay sharp
#define MB_DEPTH_TOLERANCE 0.045   // Log2 depth tolerance; roughly 3% before soft falloff
#define MB_CUT_ANGLE_COS 0.7660444 // 40 degree orientation change
#define MB_CUT_SCREEN_HEIGHT 0.15  // Screen displacement as a fraction of height; 0 disables this test
#define MB_CUT_SPEED_RATIO 3.0     // Required jump in screen speed relative to the previous interval
#define MB_MIN_FRAME_GAP 0.0001    // Seconds; ignore duplicate timestamps and float noise
#define MB_MAX_FRAME_GAP 0.1001    // Seconds, including a 3-frame gap at 30 fps
#define MB_CLEAR_RGBA 1.0, 1.0, 1.0, 0.0
#define MB_TRAIL_ALPHA 0           // 1: capture and output premultiplied RGBA for transparent export
#define MB_TRANSLUCENT_MOTION 0   // 1: blur ordinary alpha materials on their own depth layer
#define MB_DEBUG 0                 // 0: result; 1: source; 2: motion; 3: depth; 4: coverage; 5: position space
#define MB_EXTEND_FOREGROUND 1     // 0: use the P0 within-surface blur
#define MB_LAYERED_TRAIL 0         // 1: retain a second trail direction at a distinct depth
#define MB_DENSE_FOREGROUND_TAPS 0 // 1: long trails sample every pixel along their dominant axis
#define MB_TRAIL_SPREAD 0.35       // Outer trail width grows by this per px of distance; 0: 0.2.0
#define MB_LINEAR_COLOR 1          // 0: point-sampled trail colour (0.2.0)
#define MB_LINEAR_LIGHT 0          // 1: accumulate sRGB scene color in linear light
#define MB_SAMPLE_JITTER 0         // 1: shift trail taps within each interval by a fixed per-pixel phase
#define MB_OUTPUT_DITHER 0        // 1: ordered dithering at 8-bit output quantization
#define MB_EDGE_BACKGROUND 1     // 0: inner side of moving silhouettes stays opaque (0.2.0)
#define MB_OUTLINE_SEARCH 3        // Px searched around native outline pixels for surface motion
#define MB_OUTLINE_FRINGE 1        // Antialiased outline fringe moves with the outline; 0: stays put
#define MB_OUTLINE_MOTION 1       // 0: disable outline coverage and velocity repair
#define MB_AUTO_MODEL_MOTION 1     // PMD/PMX use vertex history by default
#define MB_ACCESSORY_MOTION 0      // 1: .x accessories use rigid matrix history
#define MB_HISTORY_SIZE 512        // Square vertex atlas used by MotionGeometry.fx
#define MB_KEEP_OBJECT_MOTION_ON_CUT 0 // 1: store world-space history and keep model motion across cuts
#define MB_TELEPORT_DISTANCE 50.0  // World units per history interval; 0 disables the check
