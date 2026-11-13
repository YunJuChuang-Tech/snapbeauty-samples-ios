"""Render the sample's own geometric mark; no external artwork is used."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / "App/Assets.xcassets"
icon = root / "AppIcon.appiconset"
icon.mkdir(parents=True, exist_ok=True)
size = 4096
image = Image.new("RGB", (size, size), "#101311")
draw = ImageDraw.Draw(image)
def point(x, y): return round(x * size), round(y * size)
color = "#ddff9a"
width = round(size * .045)
draw.ellipse((*point(.22, .23), *point(.70, .81)), outline=color, width=width)
curve = []
for i in range(201):
    t = i / 200
    curve.append(point((1-t)**2*.35 + 2*(1-t)*t*.46 + t*t*.57,
                       (1-t)**2*.62 + 2*(1-t)*t*.74 + t*t*.62))
draw.line(curve, fill=color, width=width, joint="curve")
draw.line([point(.74, .16), point(.74, .40)], fill=color, width=width)
draw.line([point(.62, .28), point(.86, .28)], fill=color, width=width)
image.resize((1024, 1024), Image.Resampling.LANCZOS).save(icon / "AppIcon.png")
(icon / "Contents.json").write_text(json.dumps({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, indent=2) + "\n", encoding="utf-8", newline="\n")
(root / "Contents.json").write_text('{"info":{"author":"xcode","version":1}}\n', encoding="utf-8", newline="\n")
print("Generated the original 1024px opaque iOS icon.")
