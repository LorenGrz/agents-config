# annotate.py module
Read when: annotating several elements with automatic label placement, locating pixel coordinates, or diffing two screenshots. The code is `scripts/annotate.py`.

## annotate_image

```python
from annotate import annotate_image

result = annotate_image(
    'screenshot.png',
    [
        {'elem': (560, 275, 635, 390), 'label': 'button', 'draw_box': True},
        {'elem': (105, 453, 236, 470), 'label': 'status text'},
    ],
    debug=True,
)
result.save('annotated.png')
```

- `elem`: `(x1, y1, x2, y2)` tight bounding box — must be exact pixel coordinates
- `label`: text label (supports `\n` for multi-line)
- `draw_box`: if `True`, draws a rounded rectangle around the element plus a straight line to the label, no arrowhead. If `False` (default), draws a V-shaped arrowhead with rounded line caps pointing at the element
- `debug`: shows targeting rectangles and candidate heatmap for placement validation
- Keyword options: `font_path`, `font_size` (default 32), `color` (default `#FF9F1C`), `stroke_width` (default 5)

## Coordinate grid helper

```python
from annotate import grid_image

grid = grid_image('screenshot.png', step=100)
grid.save('grid.png')
```

Then verify with small crops:

```python
from PIL import Image
img = Image.open('screenshot.png')
crop = img.crop((x1 - 20, y1 - 20, x2 + 20, y2 + 20))
crop.save('verify.png')
```

## Debug mode colors

| Color | Meaning |
|-------|---------|
| Cyan | Target element box (elem + padding) |
| Gray | Exclusion zone (MIN_ARROW buffer) |
| Red→Green | Candidate heatmap (red=bad, green=good) |
| Magenta | Chosen label position |
| Orange | Final rendered annotation |

## Algorithm overview

1. **Ring search**: candidates between MIN_ARROW (25px) and MAX_ARROW (120px) from element edge
2. **Contrast scoring**: prefers placements where label text is readable — `abs(avg_brightness - 147) - std * 0.3 - dist * 0.02`
3. **Joint resolution**: candidates computed independently, placed greedily (best score first)
4. **Hard blocks**: labels cannot overlap any other annotation's element or breathing box
5. **Proximity penalty**: labels within 40px of other placed boxes get a score penalty
6. **Arrow crossing penalty**: -50 for arrows crossing already-placed arrows

## Image diffing

Find what changed between two screenshots programmatically. Needs `scipy`.

```python
from annotate import diff_images

clusters, debug_img = diff_images(
    'before.png', 'after.png',
    threshold=30,     # pixel difference floor (0-255)
    min_pixels=300,   # ignore tiny noise clusters
    dilate=5,         # merge nearby changed pixels
    debug=True,       # render heatmap overlay
)

# clusters = [(x1, y1, x2, y2, pixel_count), ...] sorted largest-first
if debug_img:
    debug_img.save('diff-debug.png')

# Feed clusters into annotate_image:
annotations = [
    {'elem': (x1, y1, x2, y2), 'label': f'Change #{i+1}', 'draw_box': True}
    for i, (x1, y1, x2, y2, _) in enumerate(clusters[:3])
]
```

**Debug heatmap colors:** Blue = small difference, Yellow = medium, Red = large, Cyan boxes = cluster bounding boxes.

**When to use:** subtle opacity changes, dashed lines, minor color shifts, anti-aliasing differences.
**When NOT to use:** any change you can see by eye — annotate directly for better labels.
