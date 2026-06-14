#!/usr/bin/env python3
"""
PixelLab API Character Generator
================================
遊戲：2D Castlevania-style Rogue-lite (Godot 4)
用途：使用 PixelLab API 生成 Pixel Art 角色 Sprite
API文檔：https://api.pixellab.ai/v2/llms.txt

規格 (來自 GDD):
  - Tile 大小：8×8 px
  - 相機縮放：×4 (顯示 32px/tile)
  - 角色高度：約 22px (~2.75 tiles)
  - 風格：Pixel Art, Castlevania-style, 側視圖
"""

import json
import base64
import os
import sys
from pathlib import Path
from datetime import datetime

# ============================================================
# 配置
# ============================================================
API_TOKEN = "956460ee-978e-4d60-999a-f4b0f567bb48"
BASE_URL = "https://api.pixellab.ai/v2"
OUTPUT_DIR = Path(__file__).parent.parent.parent / "assets" / "characters"

# ============================================================
# 角色定義 (依 GDD 設計)
# ============================================================
CHARACTERS = [
    {
        "id": "player_base",
        "name": "Player Base",
        "description": (
            "2D side-scrolling platformer hero, male warrior with simple leather armor, "
            "holding a short sword, 8-bit pixel art style, castlevania dark fantasy, "
            "side view facing left, small character about 22 pixels tall, "
            "transparent background, clean pixel art, minimal colors, "
            "dark dungeon atmosphere, retro game sprite"
        ),
        "image_size": {"width": 32, "height": 32},
        "no_background": True,
        "priority": 1,
    },
    {
        "id": "enemy1_patrol",
        "name": "Enemy1 - Ground Patrol",
        "description": (
            "small skeleton soldier enemy, wearing tattered cloth, simple sword, "
            "8-bit pixel art, side view, dark dungeon castlevania style, "
            "transparent background, 22 pixels tall, retro game sprite, "
            "dark fantasy, minimal palette"
        ),
        "image_size": {"width": 32, "height": 32},
        "no_background": True,
        "priority": 2,
    },
    {
        "id": "enemy3_ranged",
        "name": "Enemy3 - Ranged Archer",
        "description": (
            "goblin archer enemy, holding a short bow, ready to shoot, "
            "8-bit pixel art, side view facing left, dark dungeon style, "
            "transparent background, 22 pixels tall, castlevania style, "
            "retro game sprite, minimal colors"
        ),
        "image_size": {"width": 32, "height": 32},
        "no_background": True,
        "priority": 3,
    },
    {
        "id": "enemy2_shield",
        "name": "Enemy2 - Shield Soldier",
        "description": (
            "armored enemy soldier with round shield, short spear, "
            "8-bit pixel art, side view, dark castlevania dungeon style, "
            "transparent background, 22 pixels tall, retro game sprite"
        ),
        "image_size": {"width": 32, "height": 32},
        "no_background": True,
        "priority": 4,
    },
    {
        "id": "boss_preview",
        "name": "Boss Preview",
        "description": (
            "large dark fantasy boss monster, demon lord with horns and dark armor, "
            "8-bit pixel art, side view, castlevania style, "
            "transparent background, 48 pixels tall, imposing presence, "
            "retro game sprite, dramatic dark atmosphere"
        ),
        "image_size": {"width": 48, "height": 48},
        "no_background": True,
        "priority": 5,
    },
]

# ============================================================
# API 工具函數
# ============================================================

def get_headers():
    return {
        "Authorization": f"Bearer {API_TOKEN}",
        "Content-Type": "application/json",
    }


def check_balance():
    """檢查帳戶餘額"""
    import urllib.request
    import urllib.error
    
    req = urllib.request.Request(
        f"{BASE_URL}/balance",
        headers=get_headers(),
        method="GET"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
            sub = data.get("subscription", {})
            print(f"📊 帳戶狀態：")
            print(f"   訂閱：{sub.get('status', 'N/A')} ({sub.get('plan', 'Trial')})")
            print(f"   剩餘生成次數：{sub.get('generations', 0):.1f} / {sub.get('total', 40)}")
            return data
    except urllib.error.HTTPError as e:
        print(f"❌ 無法取得餘額：{e.code} {e.reason}")
        return None


def generate_character_pixflux(char_def: dict) -> dict | None:
    """
    使用 create-image-pixflux 端點生成角色
    文檔：POST /v2/create-image-pixflux
    支援：透明背景, init image, forced palette
    大小：最小 32x32，最大 400x400
    """
    import urllib.request
    import urllib.error

    payload = {
        "description": char_def["description"],
        "image_size": char_def["image_size"],
        "no_background": char_def.get("no_background", True),
        # 可選參數
        # "guidance_scale": 7.5,
        # "outline_style": "hard",
    }
    
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/create-image-pixflux",
        data=data,
        headers=get_headers(),
        method="POST"
    )
    
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read().decode())
            return result
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"❌ HTTP {e.code}: {body}")
        return None
    except Exception as e:
        print(f"❌ 請求失敗：{e}")
        return None


def save_base64_image(b64_data: str, filepath: Path):
    """將 base64 圖片數據保存為 PNG 文件"""
    # 處理 data URI 格式: "data:image/png;base64,..."
    if "," in b64_data:
        b64_data = b64_data.split(",", 1)[1]
    
    img_bytes = base64.b64decode(b64_data)
    filepath.write_bytes(img_bytes)
    print(f"✅ 已保存：{filepath} ({len(img_bytes)} bytes)")


# ============================================================
# 主程序
# ============================================================

def main():
    print("=" * 60)
    print("🎮 PixelLab 遊戲角色生成器")
    print(f"📁 輸出目錄：{OUTPUT_DIR}")
    print("=" * 60)
    print()
    
    # 確認輸出目錄
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # 檢查餘額
    balance = check_balance()
    if not balance:
        sys.exit(1)
    
    sub = balance.get("subscription", {})
    remaining = sub.get("generations", 0)
    
    print()
    
    # 決定要生成哪些角色
    chars_to_generate = [c for c in CHARACTERS if c["priority"] <= 3]  # 只生成前3個
    
    print(f"📋 計劃生成：{len(chars_to_generate)} 個角色")
    print(f"   剩餘配額：{remaining:.1f} 次")
    print()
    
    if remaining < len(chars_to_generate):
        print(f"⚠️  警告：配額不足（需要 {len(chars_to_generate)} 次，剩餘 {remaining:.1f} 次）")
        chars_to_generate = chars_to_generate[:int(remaining)]
        print(f"   將只生成前 {len(chars_to_generate)} 個角色")
    
    # 詢問確認
    print("是否繼續生成？(y/n): ", end="", flush=True)
    confirm = input().strip().lower()
    if confirm != "y":
        print("已取消")
        return
    
    print()
    
    # 生成角色
    results = []
    for i, char in enumerate(chars_to_generate):
        print(f"[{i+1}/{len(chars_to_generate)}] 生成：{char['name']}")
        print(f"   Prompt: {char['description'][:80]}...")
        print(f"   大小: {char['image_size']['width']}×{char['image_size']['height']} px")
        
        result = generate_character_pixflux(char)
        
        if result and "image" in result:
            img_data = result["image"]
            if isinstance(img_data, dict):
                b64 = img_data.get("base64", "")
            else:
                b64 = str(img_data)
            
            if b64:
                # 保存圖片
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = OUTPUT_DIR / f"{char['id']}_{timestamp}.png"
                save_base64_image(b64, filename)
                
                usage = result.get("usage", {})
                print(f"   費用：${usage.get('usd', 0):.4f} USD")
                
                results.append({
                    "id": char["id"],
                    "name": char["name"],
                    "file": str(filename),
                    "size": char["image_size"],
                    "usage": usage,
                })
            else:
                print(f"❌ 沒有圖片數據")
        else:
            print(f"❌ 生成失敗")
        
        print()
    
    # 保存摘要
    summary_file = OUTPUT_DIR / "generation_log.json"
    summary = {
        "timestamp": datetime.now().isoformat(),
        "generated": results,
        "total_characters": len(results),
    }
    summary_file.write_text(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"📝 生成日誌：{summary_file}")
    
    print()
    print("=" * 60)
    print(f"✨ 完成！共生成 {len(results)} 個角色")
    print("=" * 60)


if __name__ == "__main__":
    main()
