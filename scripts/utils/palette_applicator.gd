@tool
extends Node
## PaletteApplicator — 色板套用器
## ─────────────────────────────────────────────────────
## 用途：將此節點掛為 TileMapLayer（Appearance）的子節點。
##       在 Inspector 從下拉選單選色，自動更新父節點的 ShaderMaterial。
##
## 使用步驟：
##   1. 在 Appearance（TileMapLayer）→ 右鍵 → Add Child Node → Node
##   2. 在 Inspector 點 Script → 指定這個檔案
##   3. 選 Fill Color（填充色）和 Outline Color（輪廓色）
##   4. 確認父節點 Appearance 已掛好 ShaderMaterial（mrmotext_palette_swap.gdshader）
## ─────────────────────────────────────────────────────

## ── 34 色色板枚舉（與 palette.pal 完全對應）────────────
enum 色板 {
	深棕灰    = 0,   ## #363232
	深棕      = 1,   ## #453C3C
	玫瑰棕    = 2,   ## #62494C
	暗紅      = 3,   ## #7F4A50
	橄欖綠    = 4,   ## #56774A
	苔綠      = 5,   ## #65725F
	藕灰      = 6,   ## #75656A
	琥珀棕    = 7,   ## #8A5E40
	胭脂紅    = 8,   ## #A75064
	玫瑰粉    = 9,   ## #AB6E7C
	番茄紅    = 10,  ## #E55C5C
	橙紅      = 11,  ## #D66B48
	薄荷綠    = 12,  ## #5DA16E
	金橙      = 13,  ## #E09656
	膚色      = 14,  ## #D49C73
	杏橙      = 15,  ## #E7946D
	萊姆綠    = 16,  ## #B1D368
	黃色      = 17,  ## #EECF5A
	鋼藍      = 18,  ## #436794
	紫紅      = 19,  ## #9D5789
	矢車菊藍  = 20,  ## #6F81B3
	天空藍    = 21,  ## #77BCD6
	中灰      = 22,  ## #978C8E
	藍灰      = 23,  ## #8599B0
	桃粉      = 24,  ## #E4A691
	淡金      = 25,  ## #E9CEA1
	薰衣草    = 26,  ## #BE8EC1
	粉紅      = 27,  ## #EDBCCC
	薄荷      = 28,  ## #B1DECF
	銀灰      = 29,  ## #C2C2C2
	淡蘆薈    = 30,  ## #DFE8D3
	奶油      = 31,  ## #F1E9D4
	薰衣草白  = 32,  ## #F1E5F8
	近白      = 33,  ## #F2F9F8
}

## 填充色（白色區域換成這個顏色）
@export var fill_color: 色板 = 色板.近白:
	set(v):
		fill_color = v
		_apply()

## 輪廓色（黑色輪廓換成這個顏色）
@export var outline_color: 色板 = 色板.深棕灰:
	set(v):
		outline_color = v
		_apply()

# ── 內部 ────────────────────────────────────────────────
func _ready() -> void:
	_apply()

func _apply() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mat := parent.material as ShaderMaterial
	if mat == null:
		push_warning("PaletteApplicator：父節點沒有 ShaderMaterial，請先在 Appearance 掛上 mrmotext_palette_swap.gdshader")
		return
	mat.set_shader_parameter("fill_index",    int(fill_color))
	mat.set_shader_parameter("outline_index", int(outline_color))
