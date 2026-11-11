"""Build the invisible PMX model used by the MME control bindings."""

from pathlib import Path
from struct import pack


MORPHS = (
    # MMD panels: 1 eyebrow, 2 eye, 3 mouth.
    ("Strength +", 1),
    ("Strength -", 1),
    ("Shutter +", 2),
    ("Shutter -", 2),
    ("Streak +", 3),
    ("Streak -", 3),
)


def pmx_text(value):
    encoded = value.encode("utf-16-le")
    return pack("<i", len(encoded)) + encoded


def build_controller():
    # PMX 2.0, UTF-16LE, no extra UVs, one-byte indices.
    data = bytearray(b"PMX " + pack("<f9B", 2.0, 8, 0, 0, 1, 1, 1, 1, 1, 1))
    for value in (
        "AMB Controller", "AMB Controller",
        "AdvancedMotionBlur P1", "Morph weights control AdvancedMotionBlur in MME.",
    ):
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
    for index in range(len(MORPHS)):
        data.extend(pack("<Bb", 1, index))
    data.extend(pack("<ii", 0, 0))  # Rigid bodies and joints.
    return data


if __name__ == "__main__":
    source_dir = Path(__file__).resolve().parents[1] / "src"
    (source_dir / "AdvancedMotionBlurController.pmx").write_bytes(build_controller())
