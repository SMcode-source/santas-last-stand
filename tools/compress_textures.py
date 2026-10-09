"""Forces web-friendly import settings on every texture under assets/.

GPU (VRAM) compression and mipmaps for everything; normal maps flagged as such;
roughness / AO / ARM maps and normal maps capped at 512 px (the detail barely
shows at full size); only the snow ground, which fills the screen, keeps 1K normals.
Run from the project root after adding textures, then let Godot reimport.
"""
import pathlib
import re

SMALL = ("roughness", "rough", "_ao", "ao.", "arm")
NORMAL = ("normal", "nor_gl")

for path in pathlib.Path("assets").rglob("*.import"):
    if not path.name.endswith((".jpg.import", ".png.import")):
        continue
    name = path.name.lower()
    text = path.read_text(encoding="utf-8")
    original = text
    text = re.sub(r"compress/mode=\d+", "compress/mode=2", text)
    text = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=true", text)
    is_normal = any(k in name for k in NORMAL)
    text = re.sub(r"compress/normal_map=\d+", "compress/normal_map=" + ("1" if is_normal else "0"), text)
    small = any(k in name for k in SMALL) or (is_normal and "snow_02" not in str(path))
    text = re.sub(r"process/size_limit=\d+", "process/size_limit=" + ("512" if small else "0"), text)
    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        print("updated", path)
