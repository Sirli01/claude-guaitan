"""
将 floor_1_scene.gd 切换为建筑白膜模式（截图用）
运行完成后截图，截完后用 git checkout HEAD -- scripts/levels/floor_1_scene.gd 还原
"""
from pathlib import Path

FILE = Path(__file__).resolve().parents[1] / "scripts" / "levels" / "floor_1_scene.gd"

with open(FILE, encoding="utf-8") as f:
    content = f.read()

# ── 1. 地板背景色 → 暖白色 ──────────────────────────────────────────────
content = content.replace(
    "floor_rect.color = Color(0.06, 0.05, 0.05)",
    "floor_rect.color = Color(0.88, 0.87, 0.85)  # 白膜背景"
)

# ── 2. 走廊地板 → 浅蓝灰 ──────────────────────────────────────────────
corridor_colors = [
    "Color(0.24, 0.26, 0.31)",
    "Color(0.2, 0.24, 0.3)",
]
for c in corridor_colors:
    content = content.replace(c, "Color(0.70, 0.73, 0.80)")

# ── 3. 房间地板 → 暖浅灰（略区别于走廊）──────────────────────────────
room_floor_colors = [
    "Color(0.28, 0.24, 0.2)",
    "Color(0.31, 0.22, 0.2)",
    "Color(0.21, 0.3, 0.25)",
    "Color(0.29, 0.26, 0.18)",
    "Color(0.27, 0.21, 0.28)",
    "Color(0.25, 0.21, 0.34)",
    "Color(0.21, 0.27, 0.34)",
    "Color(0.28, 0.26, 0.33)",
    "Color(0.25, 0.31, 0.23)",
    "Color(0.3, 0.23, 0.18)",
    "Color(0.17, 0.22, 0.26)",
]
for c in room_floor_colors:
    content = content.replace(c, "Color(0.88, 0.86, 0.82)")

# ── 4. 墙体 → 深灰（清晰可见）────────────────────────────────────────
wall_colors = [
    "Color(0.12, 0.08, 0.06)",
    "Color(0.1, 0.07, 0.05)",
]
for c in wall_colors:
    content = content.replace(c, "Color(0.18, 0.15, 0.13)")

# ── 5. 家具 → 中灰 ────────────────────────────────────────────────────
furniture_colors = [
    "Color(0.16, 0.1, 0.08)",
    "Color(0.15, 0.1, 0.08)",
    "Color(0.14, 0.1, 0.07)",
    "Color(0.12, 0.09, 0.06)",
    "Color(0.18, 0.12, 0.1)",
    "Color(0.18, 0.12, 0.08)",
]
for c in furniture_colors:
    content = content.replace(c, "Color(0.48, 0.43, 0.38)")

# ── 6. 房间标签文字 → 深色可读 ────────────────────────────────────────
content = content.replace(
    "Color(0.3, 0.25, 0.2)",
    "Color(0.12, 0.09, 0.07)"
)

# ── 7. 删除 add_room_ceiling 调用（逐行删除，避免截断 Vector2 嵌套括号）─
lines = content.split("\n")
filtered = [l for l in lines if "\tadd_room_ceiling(" not in l]
content = "\n".join(filtered)

# ── 8. 关闭黑暗效果（截图用全亮）──────────────────────────────────────
content = content.replace(
    "enable_darkness(0.06, 3.0)",
    "# enable_darkness(0.06, 3.0)  # 白膜截图：暂关黑暗"
)

# ── 9. 光照系统：关掉个人光（手机手电筒）让整体均匀亮 ────────────────
# 把开灯操作改为直接打开（已在 phone_intro 里处理，无需额外改）

with open(FILE, "w", encoding="utf-8") as f:
    f.write(content)

print("白膜模式已写入！")
print("截图完成后执行：git checkout HEAD -- scripts/levels/floor_1_scene.gd")
