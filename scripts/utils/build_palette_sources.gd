@tool
extends EditorScript
## build_palette_sources.gd
## ─────────────────────────────────────────────────────────────────
## 前置條件：
##   1. 已執行 scripts/tools/generate_palette_pngs.py 生成 34 張 PNG
##   2. 在 Godot FileSystem 右上角按 Rescan，等待 PNG 匯入完成
##
## 執行：Script 編輯器開啟此檔 → File → Run（Ctrl+Shift+X）
##
## 結果：mrmotext_world_tileset.tres 有 35 個 Sources：
##   Source 0      = 原始黑白（保留物理碰撞設定）
##   Source 1~34   = 34 種彩色版本（直接染色 PNG，無需 Shader）
## ─────────────────────────────────────────────────────────────────

const TILESET_PATH := "res://assets/tilesets/mrmotext/mrmotext_world_tileset.tres"
const COLORED_DIR  := "res://assets/tilesets/mrmotext/colored/"

const COLOR_FILES: Array[String] = [
	"color_00_shenzonghui.png",  # 深棕灰
	"color_01_shenzong.png",     # 深棕
	"color_02_meiguizong.png",   # 玫瑰棕
	"color_03_anan.png",         # 暗紅
	"color_04_ganlanlv.png",     # 橄欖綠
	"color_05_tailv.png",        # 苔綠
	"color_06_ouhui.png",        # 藕灰
	"color_07_hupozong.png",     # 琥珀棕
	"color_08_yanzhihong.png",   # 胭脂紅
	"color_09_meiguifen.png",    # 玫瑰粉
	"color_10_fanqiehong.png",   # 番茄紅
	"color_11_chenghong.png",    # 橙紅
	"color_12_bohelv.png",       # 薄荷綠
	"color_13_jincheng.png",     # 金橙
	"color_14_fuse.png",         # 膚色
	"color_15_xincheng.png",     # 杏橙
	"color_16_laimeng.png",      # 萊姆綠
	"color_17_huang.png",        # 黃色
	"color_18_ganlanlv2.png",    # 鋼藍
	"color_19_zihong.png",       # 紫紅
	"color_20_shiya.png",        # 矢車菊藍
	"color_21_tiankong.png",     # 天空藍
	"color_22_zhonghui.png",     # 中灰
	"color_23_lanhui.png",       # 藍灰
	"color_24_taofen.png",       # 桃粉
	"color_25_danjin.png",       # 淡金
	"color_26_xunyi.png",        # 薰衣草
	"color_27_fen.png",          # 粉紅
	"color_28_bohe.png",         # 薄荷
	"color_29_yinhui.png",       # 銀灰
	"color_30_luhui.png",        # 淡蘆薈
	"color_31_naiyu.png",        # 奶油
	"color_32_xunyi2.png",       # 薰衣草白
	"color_33_jingbai.png",      # 近白
]

const COLOR_NAMES: Array[String] = [
	"深棕灰","深棕","玫瑰棕","暗紅","橄欖綠","苔綠","藕灰","琥珀棕",
	"胭脂紅","玫瑰粉","番茄紅","橙紅","薄荷綠","金橙","膚色","杏橙",
	"萊姆綠","黃色","鋼藍","紫紅","矢車菊藍","天空藍","中灰","藍灰",
	"桃粉","淡金","薰衣草","粉紅","薄荷","銀灰","淡蘆薈","奶油",
	"薰衣草白","近白",
]

# ────────────────────────────────────────────────────────────────
func _run() -> void:
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("  [Build Palette Sources] 建立 34 彩色 PNG Sources")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# ── 載入 TileSet ──────────────────────────────────────────
	var tileset := load(TILESET_PATH) as TileSet
	if not tileset:
		printerr("❌ 找不到 TileSet：", TILESET_PATH)
		return

	if not tileset.has_source(0):
		printerr("❌ 沒有 source 0")
		return
	var src0 := tileset.get_source(0) as TileSetAtlasSource
	if not src0:
		printerr("❌ source 0 不是 AtlasSource")
		return

	var tile_size := src0.texture_region_size
	print("  Source 0: %d tiles, tile_size=%s" % [src0.get_tiles_count(), tile_size])

	# ── Step 1：清除 source 0 的 alternative tiles ────────────
	print("  [1/3] 清除 source 0 alternative tiles...")
	for ti in range(src0.get_tiles_count()):
		var coords := src0.get_tile_id(ti)
		var alts: Array[int] = []
		for ai in range(src0.get_alternative_tiles_count(coords)):
			var aid := src0.get_alternative_tile_id(coords, ai)
			if aid != 0:
				alts.append(aid)
		for aid in alts:
			src0.remove_alternative_tile(coords, aid)
	print("  alt tiles 清除完成")

	# ── Step 2：移除舊的彩色 sources（保留 0）────────────────
	print("  [2/3] 移除舊 sources...")
	var to_remove: Array[int] = []
	for si in range(tileset.get_source_count()):
		var sid := tileset.get_source_id(si)
		if sid != 0:
			to_remove.append(sid)
	for sid in to_remove:
		tileset.remove_source(sid)
	print("  移除 %d 個舊 sources" % to_remove.size())

	# ── Step 3：建立 34 個彩色 PNG Sources ───────────────────
	print("  [3/3] 建立 34 個 PNG Sources...")

	# 收集 source 0 的所有 tile 座標
	var all_coords: Array[Vector2i] = []
	for ti in range(src0.get_tiles_count()):
		all_coords.append(src0.get_tile_id(ti))

	var created := 0
	var missing := 0

	for i in range(34):
		var png_path := COLORED_DIR + COLOR_FILES[i]
		var tex := load(png_path) as Texture2D
		if not tex:
			printerr("  ⚠️  找不到/未匯入：%s（請先 Rescan）" % png_path)
			missing += 1
			continue

		var new_src := TileSetAtlasSource.new()
		new_src.resource_name     = COLOR_NAMES[i]
		new_src.texture           = tex
		new_src.texture_region_size = tile_size

		# 複製 tile 座標（不含物理/導航等額外資料）
		for coords in all_coords:
			new_src.create_tile(coords)

		tileset.add_source(new_src, i + 1)   # source id = 1~34
		created += 1
		print("  Source %2d: %s" % [i + 1, COLOR_NAMES[i]])

	# ── 儲存 ─────────────────────────────────────────────────
	print("  儲存 TileSet...")
	var err := ResourceSaver.save(tileset, TILESET_PATH)

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	if err == OK:
		print("✅ 完成！TileSet 共 %d sources（0=黑白，1~34=彩色 PNG）" \
			% tileset.get_source_count())
		if missing > 0:
			print("   ⚠️  %d 個 PNG 未匯入，請 Rescan 後重新執行" % missing)
	else:
		printerr("❌ 儲存失敗（Error %d）" % err)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
