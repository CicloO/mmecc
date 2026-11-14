// Model-only motion blur: assign to a whole PMX/PMD object on the GeometryData
// offscreen tab. The object blurs from its own movement; camera movement is ignored.
#define MB_VERTEX_HISTORY 1
#define MB_OBJECT_ONLY 1
#include "Geometry.fxh"
