"""生成「玄机 · 六爻卦象」应用图标。

纯几何绘制：深墨底 + 鎏金外环 + 八卦爻画 + 中央太极（阴阳鱼）。
输出高分辨率 PNG 及多尺寸 Windows .ico。
"""

import math
import os

from PIL import Image, ImageDraw

# 主题色（与 lib/ui/theme.dart 对应）。
INK = (14, 17, 22, 255)
INK2 = (22, 27, 34, 255)
GOLD = (215, 190, 126, 255)
GOLD_DEEP = (169, 132, 60, 255)
LIGHT = (231, 226, 212, 255)

SS = 4  # 超采样倍率
SIZE = 1024


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(4))


def make_base(size):
    """径向渐变底 + 微暗角。"""
    img = Image.new("RGBA", (size, size), INK)
    px = img.load()
    cx = cy = size / 2
    maxr = size * 0.72
    inner = (26, 32, 40, 255)
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy) / maxr
            d = min(d, 1.0)
            px[x, y] = lerp(inner, INK, d)
    return img


def draw_trigram_ticks(draw, cx, cy, r, size):
    """外环内侧的八卦爻画（八个方位，每个三爻）。"""
    # 后天/先天不强求，纯装饰性八组三爻。
    patterns = [
        (1, 1, 1),  # 乾
        (0, 1, 1),
        (1, 0, 1),
        (0, 0, 1),
        (1, 1, 0),
        (0, 1, 0),
        (1, 0, 0),
        (0, 0, 0),  # 坤
    ]
    seg_w = size * 0.052
    gap = size * 0.016
    line_h = size * 0.011
    line_gap = size * 0.013
    for i, pat in enumerate(patterns):
        ang = math.radians(i * 45 - 90)
        bx = cx + r * math.cos(ang)
        by = cy + r * math.sin(ang)
        # 每个方位以径向为法线绘制三条爻。
        nx, ny = math.cos(ang), math.sin(ang)
        tx, ty = -ny, nx  # 切向
        for row, val in enumerate(pat):
            off = (row - 1) * (line_h + line_gap)
            lx = bx + nx * off
            ly = by + ny * off
            if val:  # 阳爻：整条
                _thick_line(draw, lx, ly, tx, ty, seg_w, line_h)
            else:  # 阴爻：断开两段
                half = seg_w / 2 - gap / 2
                cxo = tx * (half / 2 + gap / 2)
                cyo = ty * (half / 2 + gap / 2)
                _thick_line(draw, lx - cxo, ly - cyo, tx, ty, half, line_h)
                _thick_line(draw, lx + cxo, ly + cyo, tx, ty, half, line_h)


def _thick_line(draw, cx, cy, tx, ty, length, thick):
    x1 = cx - tx * length / 2
    y1 = cy - ty * length / 2
    x2 = cx + tx * length / 2
    y2 = cy + ty * length / 2
    draw.line([(x1, y1), (x2, y2)], fill=GOLD, width=max(1, round(thick)))


def draw_taiji(img, cx, cy, r, rot_deg=-30):
    """在透明层上绘制太极，再旋转贴回。"""
    pad = int(r * 1.4)
    layer = Image.new("RGBA", (pad * 2, pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    lx = ly = pad
    R = r
    # 亮底整圆。
    d.ellipse([lx - R, ly - R, lx + R, ly + R], fill=LIGHT)
    # 暗半（右半）。
    d.pieslice([lx - R, ly - R, lx + R, ly + R], -90, 90, fill=INK2)
    # 上下两个半圆调和。
    d.ellipse([lx - R / 2, ly - R, lx + R / 2, ly], fill=INK2)  # 上：暗
    d.ellipse([lx - R / 2, ly, lx + R / 2, ly + R], fill=LIGHT)  # 下：亮
    # 鱼眼。
    eye = R / 5
    d.ellipse([lx - eye, ly - R / 2 - eye, lx + eye, ly - R / 2 + eye], fill=LIGHT)
    d.ellipse([lx - eye, ly + R / 2 - eye, lx + eye, ly + R / 2 + eye], fill=INK2)
    # 金色描边。
    d.ellipse([lx - R, ly - R, lx + R, ly + R], outline=GOLD, width=max(2, R // 40))
    layer = layer.rotate(rot_deg, resample=Image.BICUBIC, center=(lx, ly))
    img.alpha_composite(layer, (cx - pad, cy - pad))


def build(size):
    S = size * SS
    img = make_base(S)
    draw = ImageDraw.Draw(img)
    cx = cy = S // 2

    # 外环。
    ring_r = S * 0.46
    draw.ellipse(
        [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
        outline=GOLD,
        width=max(2, int(S * 0.012)),
    )
    inner_ring = S * 0.415
    draw.ellipse(
        [cx - inner_ring, cy - inner_ring, cx + inner_ring, cy + inner_ring],
        outline=GOLD_DEEP,
        width=max(1, int(S * 0.004)),
    )

    # 八卦爻画。
    draw_trigram_ticks(draw, cx, cy, S * 0.355, S)

    # 中央太极。
    draw_taiji(img, cx, cy, int(S * 0.2))

    return img.resize((size, size), Image.LANCZOS)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    master = build(SIZE)

    out_png = os.path.join(root, "assets", "icon", "app_icon.png")
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    master.save(out_png)
    print("PNG ->", out_png)

    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    ico_path = os.path.join(
        root, "windows", "runner", "resources", "app_icon.ico"
    )
    master.save(ico_path, sizes=[(s, s) for s in ico_sizes])
    print("ICO ->", ico_path)


if __name__ == "__main__":
    main()
