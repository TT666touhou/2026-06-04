# VFX PlayerDust 架構設計文件

## 系統概觀

PlayerDust 改為**永久子節點**（不再每次 instantiate），掛在 player1.tscn 下，
透過公開方法由 player1.gd 呼叫。

```
Player1 (CharacterBody2D)
├── ... (既有節點)
├── FloorCast (ShapeCast2D)       ← 新增：地板顏色採樣
└── PlayerDust (Node2D)           ← 新增：雙粒子容器
    ├── BrickDebris (GPUParticles2D)
    └── DustCloud   (GPUParticles2D)
```

---

## 模組職責分工

### `FloorCast (ShapeCast2D)`
- 形狀：`RectangleShape2D` size=(10, 2)
- Position: (0, 6)，Target: (0, 4)
- 由 `player1.gd._get_floor_color()` 呼叫
- **只讀，不發射碰撞事件**

### `PlayerDust (Node2D)` + `player_dust.gd`
- 不自動播放，等待外部呼叫
- 公開 API：
  ```gdscript
  emit_bricks(terrain_normal: Vector2, launch_velocity: Vector2, floor_color: Color) -> void
  emit_dust(direction: float) -> void   # direction: -1.0 或 1.0
  ```

### `player1.gd` 觸發邏輯
```
_do_normal_jump()    → if is_on_floor(): emit_bricks(floor_normal, velocity, floor_color)
_do_wall_jump()      → emit_bricks(wall_normal, velocity, Color.GRAY)
_handle_roll() 觸發  → if is_on_floor(): emit_bricks(floor_normal, velocity, floor_color)
落地偵測            → if |velocity.x| > 10: emit_dust(sign(velocity.x))
```

---

## 地板顏色採樣演算法

```
force_shapecast_update()
  for i in collision_count:
    collider[i] is TileMapLayer?
      → to_local(collision_point) → local_to_map → cell
      → get_cell_source_id(cell) → TileSetAtlasSource
      → get_cell_atlas_coords(cell) → pixel origin
      → source.texture.get_image().get_pixel(origin + tile_sz/2)
      → return Color
  fallback → Color(0.65, 0.65, 0.65)
```

---

## BrickDebris 反射方向計算

```gdscript
# 在 emit_bricks() 內：
var reflect_dir := launch_velocity.bounce(terrain_normal).normalized()
# 將 reflect_dir 設入 ParticleProcessMaterial.direction (Vector3)
brick_mat.direction = Vector3(reflect_dir.x, reflect_dir.y, 0.0)
```

---

## DustCloud 方向計算

```gdscript
# 在 emit_dust(direction) 內：
# direction: 1.0=右走, -1.0=左走
# 粒子方向：略微斜後方（負號 = 往上且略往反方向）
dust_mat.direction = Vector3(-direction * 0.3, -1.0, 0.0).normalized()
```

---

## 粒子參數規格

### BrickDebris
| 參數 | 值 |
|---|---|
| Texture | AtlasTexture (brick_gray.png, Region=0,0,24,22) |
| Amount | 6 |
| Lifetime | 0.45s |
| One Shot | ON |
| Local Coords | OFF |
| Explosiveness | 0.9 |
| Initial Velocity Min/Max | 60 / 130 |
| Angular Velocity Min/Max | -200 / 200 °/s |
| Gravity | (0, 300, 0) |
| Scale Min/Max | 0.7 / 1.1 |
| Anim Speed Min/Max | 1.0 / 1.0 |
| Anim Offset Min/Max | 0.0 / 1.0 |
| Spread | 30° |

### DustCloud
| 參數 | 值 |
|---|---|
| Texture | 無 |
| Amount | 12 |
| Lifetime | 0.5s |
| One Shot | ON |
| Local Coords | OFF |
| Explosiveness | 0.9 |
| Direction | 動態（emit_dust 設定） |
| Initial Velocity Min/Max | 15 / 40 |
| Gravity | (0, 150, 0) |
| Scale Min/Max | 0.3 / 0.8 |
| Spread | 55° |
| Color | Color(0.667, 0.667, 0.667, 1.0) (#AAAAAA) |

---

## 注意事項

1. **舊代碼清理**：移除 player1.gd 中的 `_DUST_SCENE` preload 與 `_spawn_landing_dust()`
2. **TSCN 鎖定**：Developer 修改 .tscn 前需 `lock-scene.ps1 lock`
3. **Import 壓縮**：brick_gray.png 需確保 `compress/mode=0` 才能 `get_image()`
4. **brick_gray anim**：ParticleProcessMaterial 的 anim_speed/offset 控制幀選擇，
   不需要 AnimatedTexture（GPU Particle UV 動畫原生支援）
