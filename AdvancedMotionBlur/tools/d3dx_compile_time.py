"""Time effect compilation with d3dx9_43.dll, the compiler MME 0.37 uses.

The Windows SDK's fxc.exe uses D3DCompiler_47 and can be much faster on the
same code, so load-time regressions only show up here. Windows only; needs the
DirectX June 2010 runtime (d3dx9_43.dll in System32).

    python tools/d3dx_compile_time.py <effect.fx> [more.fx ...]

MotionGeometry.fx uses MME's `_INDEX` semantic, which d3dx9 rejects; compile a
copy with `: _INDEX` replaced by `: TEXCOORD7` (as the FXC test matrix does).
"""
import ctypes
import sys
import time
from ctypes import POINTER, WINFUNCTYPE, byref, c_long, c_uint32, c_void_p, c_wchar_p

d3dx = ctypes.WinDLL("d3dx9_43.dll")
create = d3dx.D3DXCreateEffectCompilerFromFileW
create.argtypes = [c_wchar_p, c_void_p, c_void_p, c_uint32, POINTER(c_void_p), POINTER(c_void_p)]
create.restype = c_long

# ID3DXEffectCompiler vtable: IUnknown (3), ID3DXBaseEffect (54),
# SetLiteral, GetLiteral, CompileEffect.
COMPILE_EFFECT = 3 + 54 + 2


def vcall(obj, index, restype, *argtypes):
    vtbl = ctypes.cast(obj, POINTER(POINTER(c_void_p))).contents
    return WINFUNCTYPE(restype, c_void_p, *argtypes)(vtbl[index])


def buffer_text(buf):
    if not buf:
        return ""
    ptr = vcall(buf, 3, c_void_p)(buf)
    size = vcall(buf, 4, c_uint32)(buf)
    return ctypes.string_at(ptr, size).decode("mbcs", "replace").strip("\0").strip()


def main(paths):
    failed = 0
    for path in paths:
        compiler, errors = c_void_p(), c_void_p()
        hr = create(path, None, None, 0, byref(compiler), byref(errors))
        if hr != 0:
            print(f"{path}: parse failed {hr & 0xFFFFFFFF:08x}\n{buffer_text(errors.value)}")
            failed += 1
            continue
        effect, errors = c_void_p(), c_void_p()
        start = time.perf_counter()
        hr = vcall(compiler.value, COMPILE_EFFECT, c_long, c_uint32, POINTER(c_void_p), POINTER(c_void_p))(
            compiler.value, 0, byref(effect), byref(errors))
        seconds = time.perf_counter() - start
        size = vcall(effect.value, 4, c_uint32)(effect.value) if effect.value else 0
        status = "OK" if hr == 0 else f"FAIL {hr & 0xFFFFFFFF:08x}"
        print(f"{seconds:7.2f} s  {size:7d} B  {status}  {path}")
        if hr != 0:
            print(buffer_text(errors.value))
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
