# PIL snippets
Read when: drawing one or two callouts by hand, or implementing the pop-in fade for an animated GIF.

## Hand-drawn callout

```python
from PIL import Image, ImageDraw, ImageFont

# Setup
font = ImageFont.truetype('C:/Windows/Fonts/Inkfree.ttf', 36)  # or load_default()
color = '#FF9F1C'  # orange for highlights
stroke = 5
pad = 18

img = Image.open('screenshot.png')
draw = ImageDraw.Draw(img)

# Rounded rect with padding
draw.rounded_rectangle(
    [x1 - pad, y1 - pad, x2 + pad, y2 + pad],
    radius=14, outline=color, width=stroke
)

# Leader line (same thickness as rect)
draw.line([x2 + pad, cy, x2 + pad + 40, cy - 30], fill=color, width=stroke)

# Label — same-color stroke for body, NO white stroke
draw.text(
    (x2 + pad + 45, cy - 60), 'label text',
    fill=color, font=font, stroke_width=1, stroke_fill=color
)

img.save('annotated.png')
```

## GIF pop-in fade

```python
# 2-frame pop-in at 10fps
FADE_ALPHAS = [0.50, 1.00]

for frame_idx in range(total_frames):
    if annotation_just_changed and local_idx < len(FADE_ALPHAS):
        alpha = FADE_ALPHAS[local_idx]
    else:
        alpha = 1.0
    # Apply alpha to annotation elements:
    # - pill background: fill=(r, g, b, int(base_alpha * alpha))
    # - text: fill=(*color, int(255 * alpha))
    # - rect outline: outline=(*color, int(255 * alpha))
```
