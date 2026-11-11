#if MB_KEEP_OBJECT_MOTION_ON_CUT
shared
#endif
texture AMB_CameraHistory : RENDERCOLORTARGET <
    int Width = 8;
    int Height = 1;
    string Format = "A32B32G32R32F";
>;

static const float CameraHistoryTag = 319.5;

#if MB_KEEP_OBJECT_MOTION_ON_CUT
// Match GeometryData's bit depth and size for the D3D9 MRT draw.
shared texture AMB_CutMotion : RENDERCOLORTARGET <
    string Format = "A16B16G16R16F";
>;
#endif
