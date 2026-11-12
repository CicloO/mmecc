"""Time or precompile effects with d3dx9_43.dll, the compiler MME 0.37 uses.

The Windows SDK's fxc.exe uses D3DCompiler_47 and can be much faster on the
same code, so load-time regressions only show up here. Windows only; needs the
DirectX June 2010 runtime (d3dx9_43.dll in System32).

    python tools/d3dx_compile_time.py <effect.fx> [more.fx ...]
    python tools/d3dx_compile_time.py --package-from src --out <new directory>

MotionGeometry.fx uses MME's `_INDEX` semantic, which d3dx9 rejects; compile a
copy with `: _INDEX` replaced by `: TEXCOORD7` only when timing that effect.
Packaging leaves MotionGeometry.fx as source for MME.
"""
import argparse
import ctypes
import re
import shutil
import sys
import time
from ctypes import POINTER, WINFUNCTYPE, byref, c_long, c_uint32, c_void_p, c_wchar_p
from pathlib import Path
from uuid import uuid4

d3dx = ctypes.WinDLL("d3dx9_43.dll")
create = d3dx.D3DXCreateEffectCompilerFromFileW
create.argtypes = [c_wchar_p, c_void_p, c_void_p, c_uint32, POINTER(c_void_p), POINTER(c_void_p)]
create.restype = c_long

# ID3DXEffectCompiler vtable: IUnknown (3), ID3DXBaseEffect (54),
# SetLiteral, GetLiteral, CompileEffect.
COMPILE_EFFECT = 3 + 54 + 2
EFFECT_MAGIC = bytes.fromhex("0109fffe")
PRECOMPILED = ("AdvancedMotionBlur.fx", "DepthVelocity.fx", "RigidMotion.fx")


def vcall(obj, index, restype, *argtypes):
    vtbl = ctypes.cast(obj, POINTER(POINTER(c_void_p))).contents
    return WINFUNCTYPE(restype, c_void_p, *argtypes)(vtbl[index])


def buffer_bytes(buf):
    if not buf:
        return b""
    ptr = vcall(buf, 3, c_void_p)(buf)
    size = vcall(buf, 4, c_uint32)(buf)
    return ctypes.string_at(ptr, size)

def compile_effect(path):
    compiler, parse_errors, code, errors = (c_void_p() for _ in range(4))
    try:
        hr = create(str(path), None, None, 0, byref(compiler), byref(parse_errors))
        if hr < 0:
            detail = buffer_bytes(parse_errors.value).decode("mbcs", "replace").strip("\0").strip()
            raise ValueError(f"{path}: parse failed {hr & 0xFFFFFFFF:08x}\n{detail}")
        start = time.perf_counter()
        hr = vcall(compiler.value, COMPILE_EFFECT, c_long, c_uint32, POINTER(c_void_p), POINTER(c_void_p))(
            compiler.value, 0, byref(code), byref(errors))
        seconds = time.perf_counter() - start
        if hr < 0:
            detail = buffer_bytes(errors.value).decode("mbcs", "replace").strip("\0").strip()
            raise ValueError(f"{path}: compile failed {hr & 0xFFFFFFFF:08x}\n{detail}")
        data = buffer_bytes(code.value)
        if not data.startswith(EFFECT_MAGIC):
            raise ValueError(f"{path}: compiler did not return a binary effect")
        return data, seconds
    finally:
        for pointer in (errors, code, parse_errors, compiler):
            if pointer.value:
                vcall(pointer.value, 2, c_uint32)(pointer.value)


def print_result(path, data, seconds):
    print(f"{seconds:7.2f} s  {len(data):7d} B  OK  {path}")


def time_effects(paths):
    failed = 0
    for path in paths:
        try:
            data, seconds = compile_effect(path)
        except ValueError as error:
            print(error, file=sys.stderr)
            failed += 1
        else:
            print_result(path, data, seconds)
    return 1 if failed else 0


def precompile_package(source, destination):
    source = source.resolve(strict=True)
    destination = destination.resolve()
    if destination.exists() or destination.is_relative_to(source):
        raise ValueError("Choose a new output directory outside the source package.")
    required = (*PRECOMPILED, "MotionGeometry.fx", "Geometry.fxh", "Settings.fxh", "AdvancedMotionBlur.x")
    for name in required:
        path = source / name
        if not path.is_file():
            raise ValueError(f"Source package is missing {path}")
        if path.read_bytes().startswith(EFFECT_MAGIC):
            raise ValueError(f"Use the source version of {path}")

    destination.parent.mkdir(parents=True, exist_ok=True)
    # The staging directory becomes the finished package. Let it inherit the
    # destination parent's ACL instead of publishing a private temporary directory.
    staging = destination.parent / f".amb-precompile-{uuid4().hex}"
    staging.mkdir()
    try:
        for path in source.iterdir():
            if path.is_file() and path.suffix.lower() in {".fx", ".fxh", ".x", ".pmx"}:
                shutil.copyfile(path, staging / path.name)
        if not re.search(rb":\s*_INDEX\b", (staging / "Geometry.fxh").read_bytes()):
            raise ValueError("Use the MME geometry source with its _INDEX semantic.")
        for name in PRECOMPILED:
            data, seconds = compile_effect(staging / name)
            (staging / name).write_bytes(data)
            print_result(name, data, seconds)
        staging.rename(destination)
    except (OSError, ValueError) as error:
        raise ValueError(f"{error}\nStaging files: {staging}") from error
    print(f"Precompiled package: {destination}")
    print("MotionGeometry.fx remains source. Rebuild from source after changing Settings.fxh.")


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("effects", nargs="*", type=Path)
    parser.add_argument("--package-from", type=Path, help="source package with the settings to compile")
    parser.add_argument("--out", type=Path, help="new directory for the precompiled package")
    args = parser.parse_args(argv)
    if args.package_from is not None:
        if args.effects or args.out is None:
            parser.error("--package-from requires --out and no positional effects")
        try:
            precompile_package(args.package_from, args.out)
        except (OSError, ValueError) as error:
            print(error, file=sys.stderr)
            return 1
        return 0
    if not args.effects or args.out is not None:
        parser.error("provide effect paths, or use --package-from with --out")
    return time_effects(args.effects)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
