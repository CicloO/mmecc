"""Build the invisible PMX model used by the MME control bindings."""

from pathlib import Path
from struct import pack


MORPHS = (
    # MMD panels: 1 eyebrow (amount), 2 eye (streak), 3 mouth (camera),
    # 4 other (cuts and style). Projects store morph keys by index, so keep
    # released indices and append new morphs. Index 9 was "Camera Off" in
    # 0.3.0; "Camera -" at weight 1 gives the same result.
    ("Strength +", 1),
    ("Strength -", 1),
    ("Shutter +", 1),
    ("Shutter -", 1),
    ("Streak +", 2),
    ("Streak -", 2),
    ("Threshold", 2),
    ("Force Cut", 4),
    ("Keep Camera", 4),
    ("Camera -", 3),
    ("Jitter Off", 4),
    ("Camera +", 3),
)

# Order of the sliders within each panel, independent of the indices above.
DISPLAY_ORDER = (
    "Strength +", "Strength -", "Shutter +", "Shutter -",
    "Streak +", "Streak -", "Threshold",
    "Camera +", "Camera -",
    "Force Cut", "Keep Camera", "Jitter Off",
)
assert sorted(DISPLAY_ORDER) == sorted(name for name, _ in MORPHS)


COMMENT_LOCAL = "\r\n".join((
    "AdvancedMotionBlur 控制器　作者：CicloO",
    "载入后用表情控制动态模糊，可注册关键帧。全部为 0 时与不载入相同。",
    "【眉】Strength +／-：强度最多加倍／降到 0",
    "【眉】Shutter +／-：快门角调到 360°／0°",
    "【目】Streak +／-：拖影最大长度加倍／降到 0",
    "【目】Threshold：加大速度死区，只糊快的动作",
    "【口】Camera +／-：只调镜头运动造成的模糊，最多加倍／降到 0（Camera - 为 1 时只剩角色自身动作的模糊）",
    "【他】Force Cut：≥0.5 时该帧按切镜处理",
    "【他】Keep Camera：≥0.5 时不做自动切镜判定",
    "【他】Jitter Off：≥0.5 时把颗粒状拖影换成规则的残影状拖影",
))

COMMENT_ENGLISH = "\r\n".join((
    "AdvancedMotionBlur controller by CicloO.",
    "Morph weights drive the effect and can be keyed. All zero = no change.",
    "[Eyebrow] Strength +/-: up to 2x / down to 0",
    "[Eyebrow] Shutter +/-: shutter angle to 360 / 0 degrees",
    "[Eye] Streak +/-: maximum streak length up to 2x / down to 0",
    "[Eye] Threshold: larger speed dead zone, only fast motion blurs",
    "[Mouth] Camera +/-: camera-motion blur only, up to 2x / down to 0 (Camera - at 1 keeps only object motion blur)",
    "[Other] Force Cut: >= 0.5 treats the frame as a camera cut",
    "[Other] Keep Camera: >= 0.5 disables automatic cut detection",
    "[Other] Jitter Off: >= 0.5 uses regular ghost streaks instead of grainy trails",
))


def pmx_text(value):
    encoded = value.encode("utf-16-le")
    return pack("<i", len(encoded)) + encoded


def build_controller():
    # PMX 2.0, UTF-16LE, no extra UVs, one-byte indices.
    data = bytearray(b"PMX " + pack("<f9B", 2.0, 8, 0, 0, 1, 1, 1, 1, 1, 1))
    for value in ("AMB Controller", "AMB Controller", COMMENT_LOCAL, COMMENT_ENGLISH):
        data.extend(pmx_text(value))

    # A tiny transparent triangle bound to the root. No shadows or outline.
    data.extend(pack("<i", 3))
    for position in ((0, 0, 0), (0.001, 0, 0), (0, 0.001, 0)):
        data.extend(pack("<8fBBf", *position, 0, 0, 1, 0, 0, 0, 0, 0))
    data.extend(pack("<i3Bii", 3, 0, 1, 2, 0, 1))
    data.extend(pmx_text("Invisible") * 2)
    data.extend(pack("<11fB5fbbBBB", 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
                     0, 0, 0, 0, 0, 0, -1, -1, 0, 1, 0))
    data.extend(pmx_text(""))
    data.extend(pack("<ii", 3, 1))

    data.extend(pmx_text("全ての親"))
    data.extend(pmx_text("Root"))
    data.extend(pack("<3fbiH3f", 0, 0, 0, -1, 0, 0x001E, 0, 0.1, 0))

    data.extend(pack("<i", len(MORPHS)))
    for name, panel in MORPHS:
        data.extend(pmx_text(name) * 2)
        # Each slider has one zero-offset vertex morph for MMD to register.
        data.extend(pack("<BBiB3f", panel, 1, 1, 0, 0, 0, 0))

    # MMD's special Root and Facial frames own the bone and morph entries.
    data.extend(pack("<i", 2))
    data.extend(pmx_text("Root") * 2)
    data.extend(pack("<BiBb", 1, 1, 0, 0))
    data.extend(pmx_text("表情"))
    data.extend(pmx_text("Facial"))
    data.extend(pack("<Bi", 1, len(MORPHS)))
    names = [name for name, _ in MORPHS]
    for name in DISPLAY_ORDER:
        data.extend(pack("<Bb", 1, names.index(name)))
    data.extend(pack("<ii", 0, 0))  # Rigid bodies and joints.
    return data


if __name__ == "__main__":
    source_dir = Path(__file__).resolve().parents[1] / "src"
    (source_dir / "AdvancedMotionBlurController.pmx").write_bytes(build_controller())
