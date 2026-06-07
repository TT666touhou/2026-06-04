shader_type canvas_item;
// ═══════════════════════════════════════════════════════════════
// MRMOTEXT Dual Color Swap Shader  v3
// ───────────────────────────────────────────────────────────────
// 兩個顏色選色器：
//   fill_color    → 替換「白色填充」區域
//   outline_color → 替換「黑色輪廓」區域
//
// 使用方式：
//   1. TileMapLayer → CanvasItem → Material → New ShaderMaterial
//   2. Shader → 選這個檔案
//   3. Inspector 出現兩個顏色選色器，直接點選即可
//
// 色票參考（palette.pal 34 色）：
//   #363232  #453C3C  #62494C  #7F4A50  #56774A  #65725F
//   #75656A  #8A5E40  #A75064  #AB6E7C  #E55C5C  #D66B48
//   #5DA16E  #E09656  #D49C73  #E7946D  #B1D368  #EECF5A
//   #436794  #9D5789  #6F81B3  #77BCD6  #978C8E  #8599B0
//   #E4A691  #E9CEA1  #BE8EC1  #EDBCCC  #B1DECF  #C2C2C2
//   #DFE8D3  #F1E9D4  #F1E5F8  #F2F9F8
// ═══════════════════════════════════════════════════════════════

/// 填充色 — 替換「白色」區域的顏色
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

/// 輪廓色 — 替換「黑色」輪廓的顏色
uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a < 0.01) {
		COLOR = vec4(0.0);
	} else {
		// 感知亮度（ITU-R BT.601）
		// 純黑 brightness=0 → outline_color
		// 純白 brightness=1 → fill_color
		// 中間灰色 → 兩色線性插值
		float brightness = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		COLOR.rgb = mix(outline_color.rgb, fill_color.rgb, brightness);
		COLOR.a   = tex.a;
	}
}
