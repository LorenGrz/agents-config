---
name: image-annotations
description: 'Use when annotating screenshots, diagrams, or images with callout rectangles, arrows, labels, and color-coded highlights using PIL, or when comparing two images (diff_images). Includes rules for animated GIF annotations with timing and pacing.'
---

# Image Annotations

## Objective

Add visual callouts to any image — screenshots, diagrams, architecture docs, demo frames — using PIL/Pillow. Highlights what changed or what to look at, so reviewers don't have to guess.

## When to use

- Highlight a specific area in a screenshot for a PR description
- Annotate before/after images to show what changed
- Add labels and callouts to diagrams or architecture images
- Create annotated frames for animated GIF demos

## Prerequisites

- Dependencies go in a throwaway venv, never global: `python -m venv /tmp/ann && /tmp/ann/bin/pip install -q Pillow numpy` (add `scipy` only for `diff_images`).
- The placement module is `scripts/annotate.py` in this skill folder (`annotate_image`, `grid_image`, `diff_images`). Import it by adding that folder to `sys.path` or copying the file next to your script; do not retype it.
- Font: Ink Free (`C:/Windows/Fonts/Inkfree.ttf`) is Windows-only and is the module's default. On Linux/macOS pass `font_path=` to a TTF that exists (`fc-list : file | head`), e.g. a Noto/DejaVu sans; `annotate_image` raises `OSError` otherwise.

## Workflow

1. Check `Image.open(path).size` first — HiDPI screenshots are larger than they appear (150% scaling = 1.5x CSS pixel dimensions).
2. **Always use `grid_image()` before annotating an unfamiliar image**, then verify coordinates with small crops. Scaled-down previews display images smaller than actual pixel dimensions — the error compounds as you move away from (0,0).
3. Annotate: one or two callouts by hand (snippet in `references/pil-snippets.md`); several elements with `annotate_image`, which places labels without overlap (`references/annotate-module.md`).
4. Verify with `debug=True` — always check the first annotation of a new image with debug mode.
5. Show locally first — verify before uploading to a PR.

## Rules

### Color

- **Red (`#E63946`)** — only for "bad" / "removed" things (e.g., circling a bug being fixed)
- **Yellowish-orange (`#FF9F1C`)** — for neutral highlights ("look here", "new feature", etc.)
- Never use red just because it's eye-catching — red = bad/removed

### Font

- Use **Ink Free** for a handwritten look on Windows. Without a TTF, hand-drawn code falls back to `ImageFont.load_default()` (pass `size=` on Pillow >= 10.1, otherwise the size is ignored)
- Size **36** for hand-drawn annotations on ~1400px-wide images (the module defaults to 32)
- `stroke_width=1` with `stroke_fill=<same color as fill>` — gives body without being too thick
- Do NOT use white stroke — looks like a bad glow effect

### Shapes and layout

- Prefer **rounded rectangles** over circles/ellipses — less pixelation at edges
- `draw.rounded_rectangle([x1, y1, x2, y2], radius=14, outline=color, width=5)`
- **Padding 18px** around the target content
- **All elements same thickness** — rect `width`, line `width`, and visual text weight should feel consistent (~5px)
- Place labels **close to the rect** — short leader line (25-35px). Labels can overlap content — the stroke gives enough contrast
- **Short labels work better** — wide labels have fewer valid placements. Use 1-3 words when possible
- **Take screenshots at native 1x, control display size in HTML** — use `<img width="300">` in markdown, never resize with PIL (creates artifacts)
- `elem` boxes passed to `annotate_image` must be exact pixel coordinates

### Animated GIFs

Animations have timing, transitions, and competing visual motion.

1. **Rects for big areas, arrows for small elements** — 500x300px area = rect, 200x25px element = arrow
2. **Labels go RIGHT NEXT to what they describe** — short arrow (30-80px), label adjacent. Viewer's eye shouldn't travel more than ~100px
3. **Arrow must not cross its own label** — pick the edge closest to the target
4. **No bottom bar / subtitle approach** — eyes jump between content and bar. Contextual placement only
5. **Hero message gets a bigger font** — main takeaway 64pt+, detail annotations 38pt
6. **Fade: 2-frame pop-in at 10fps** — 50% → 100% opacity (0.2s total). Easing curves look bad at low FPS (code in `references/pil-snippets.md`)
7. **Type → pause → annotate** — during fast action, show NO annotation. Pause, then add it
8. **Variable frame duration** — fast during action (100ms), slow during pauses (600-800ms), long hold for hero (500ms)
9. **Higher FPS for smooth motion** — 10fps minimum for typing/interaction

### Limitations

- PIL text rendering is basic — no rich text, no markdown
- Animated GIF annotations require frame-by-frame processing which can be slow for long recordings
- Algorithmic placement works best with 2-6 annotations; more than that may produce crowded results

## Reference

- `references/pil-snippets.md`: read when drawing a callout by hand (rounded rect + leader line + label) or implementing the GIF pop-in fade.
- `references/annotate-module.md`: read when using `scripts/annotate.py` — `annotate_image` arguments, the grid/crop helpers, debug colors, the placement algorithm, and `diff_images` for before/after screenshots.
- Source: vendored from [`github/awesome-copilot`](https://github.com/github/awesome-copilot/tree/main/skills/image-annotations) (MIT) on 2026-11-05.
