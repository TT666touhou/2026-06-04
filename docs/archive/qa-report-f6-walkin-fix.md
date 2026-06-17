# QA Report ? F6 Player Spawn Fix (room_02)
**日期**: 2026-06-14
**問題**: F6 開? area_0_room_02.tscn 時 player 不出現

## 根本原因
room_base.gd walk-in spawn 的起始位置計算錯誤：
- 舊版：player 從 SpawnMarker 外側（boundary 外 -64px）向 boundary 端走
- 結果：camera Left limit = 0，player 從 x=-64 走到 x=0，全程在 camera 邊界外不可見

## 修正?容
1. **room_base.gd** (L119-130)：
   - 舊：start = SpawnMarker.pos - dir * 64（邊界外）
   - 新：start = SpawnMarker.pos（邊界線上）→ 向室?走入
   - Player 從邊界線開始，走 64px 進入室?，全程可見

2. **room_portal.gd** (L75-76)：
   - push_error → push_warning（F6 模式下 GameWorld 不存在屬預期，不應出 ERROR）

## 靜態驗證
- Godot headless 0 ERROR 通過
- room_02 F6 log 確認：start=(0.0,-42.0), walk_into=(64.0,-42.0)

## QA 決定：允許 commit ?