"""
批量裁剪角色精灵图工具
======================
裁剪所有角色走路/待机动画帧的透明边距，并自动更新 manifest.json。
支持: 单帧PNG + 精灵表(spritesheet)

用法: python tools/crop_character_sprites.py
"""

import os
import sys
import json
import glob
from PIL import Image

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
SPRITES_ROOT = os.path.join(PROJECT_ROOT, "assets", "sprites")


def find_character_dirs():
    """找到所有包含 manifest.json 的角色目录"""
    chars = []
    for manifest_path in glob.glob(os.path.join(SPRITES_ROOT, "**", "manifest.json"), recursive=True):
        char_dir = os.path.dirname(manifest_path)
        chars.append(char_dir)
    return chars


def get_content_bbox(img: Image.Image):
    """获取图像非透明内容的边界框"""
    if img.mode != "RGBA":
        return None
    alpha = img.split()[-1]
    return alpha.getbbox()


def process_character(char_dir: str, dry_run: bool = False):
    """处理单个角色的所有帧"""
    char_name = os.path.basename(char_dir)
    manifest_path = os.path.join(char_dir, "manifest.json")

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    # 收集所有帧PNG（排除精灵表）
    frame_paths = []
    for p in glob.glob(os.path.join(char_dir, "**", "*.png"), recursive=True):
        if "sheet" in os.path.basename(p).lower():
            continue
        frame_paths.append(p)

    if not frame_paths:
        print(f"  [{char_name}] 没有找到帧文件，跳过")
        return

    # 第一步: 找到所有帧的全局内容边界
    global_min_x, global_min_y = 99999, 99999
    global_max_x, global_max_y = 0, 0

    for fp in frame_paths:
        img = Image.open(fp)
        bbox = get_content_bbox(img)
        if bbox:
            global_min_x = min(global_min_x, bbox[0])
            global_min_y = min(global_min_y, bbox[1])
            global_max_x = max(global_max_x, bbox[2])
            global_max_y = max(global_max_y, bbox[3])

    old_cw = manifest.get("canvas_width", 512)
    old_ch = manifest.get("canvas_height", 440)
    old_bl = manifest.get("baseline_y", old_ch)

    new_cw = global_max_x - global_min_x
    new_ch = global_max_y - global_min_y
    new_bl = old_bl - global_min_y

    # 确保 baseline 不超出画布
    if new_bl > new_ch:
        new_bl = new_ch
    if new_bl < 0:
        new_bl = new_ch

    print(f"  [{char_name}] 旧画布: {old_cw}x{old_ch}, baseline={old_bl}")
    print(f"              内容: {global_min_x},{global_min_y} → {global_max_x},{global_max_y}")
    print(f"              新画布: {new_cw}x{new_ch}, baseline={new_bl}")
    print(f"              节省: {old_cw*old_ch - new_cw*new_ch} 像素/帧 ({len(frame_paths)}帧)")

    if dry_run:
        print(f"              [DRY RUN] 跳过实际修改")
        return

    # 第二步: 裁剪所有帧
    for fp in frame_paths:
        img = Image.open(fp)
        cropped = img.crop((global_min_x, global_min_y, global_max_x, global_max_y))
        cropped.save(fp)

    # 第三步: 更新 manifest.json
    manifest["canvas_width"] = new_cw
    manifest["canvas_height"] = new_ch
    manifest["baseline_y"] = new_bl

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent="\t")

    print(f"              [OK] cropped {len(frame_paths)} frames + updated manifest.json")


def process_sprite_sheet(sheet_path: str, dry_run: bool = False):
    """裁剪单个精灵表（保留帧的网格对齐）"""
    img = Image.open(sheet_path)
    bbox = get_content_bbox(img)
    if not bbox:
        print(f"  [{os.path.basename(sheet_path)}] 无透明内容，跳过")
        return

    new_w = bbox[2] - bbox[0]
    new_h = bbox[3] - bbox[1]
    saved = img.width * img.height - new_w * new_h

    print(f"  [{os.path.basename(sheet_path)}] {img.width}x{img.height} → {new_w}x{new_h}")
    print(f"              边距: L={bbox[0]} T={bbox[1]} R={img.width-bbox[2]} B={img.height-bbox[3]}")
    print(f"              节省: {saved} 像素")

    if dry_run:
        print(f"              [DRY RUN] 跳过实际修改")
        return

    cropped = img.crop(bbox)
    cropped.save(sheet_path)
    print(f"              [OK] cropped")


def main():
    dry_run = "--dry-run" in sys.argv or "-n" in sys.argv

    if dry_run:
        print("=== DRY RUN 模式 (不会实际修改文件) ===\n")

    # 处理所有角色目录
    char_dirs = find_character_dirs()
    print(f"找到 {len(char_dirs)} 个角色目录\n")

    for char_dir in sorted(char_dirs):
        process_character(char_dir, dry_run)

    # 精灵表默认不裁剪（它们是源文件，游戏运行时使用的是单帧PNG）
    if "--with-sheets" in sys.argv:
        print("\n--- 精灵表 ---")
        sheet_patterns = ["**/sister_walk_sheet.png", "**/*_walk_sheet.png"]
        for pattern in sheet_patterns:
            for sheet_path in glob.glob(os.path.join(SPRITES_ROOT, pattern), recursive=True):
                process_sprite_sheet(sheet_path, dry_run)

    if dry_run:
        print("\n=== DRY RUN 完成，使用 'python tools/crop_character_sprites.py' 执行实际修改 ===")
    else:
        print("\n=== 全部完成 ===")


if __name__ == "__main__":
    main()
