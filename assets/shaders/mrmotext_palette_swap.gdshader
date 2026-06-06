shader_type canvas_item;
// ───────────────────────────────────────────────────────────
// Palette Swap Shader for MRMOTEXT 2-color tiles
// 用於 TileMapLayer，將 黑色→shadow_color，白色→highlight_color
//
// 使用方式：
//   1. 選取 TileMapLayer 節點
//   2. Inspector → CanvasItem → Material → [new ShaderMaterial]
//   3. Shader → 選這個檔案
//   4. 調整 shadow_color 和 highlight_color
// ───────────────────────────────────────────────────────────

/// 替換「黑色輪廓」的顏色（建議用目標色的暗版）
uniform vec4 shadow_color    : source_color = vec4(0.05, 0.05, 0.05, 1.0);

/// 替換「白色填充」的顏色（建議用目標主色）
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// 用亮度（灰階值）在兩色之間線性插值
	// 純黑 brightness=0 → shadow_color
	// 純白 brightness=1 → highlight_color
	float brightness = dot(tex.rgb, vec3(0.299, 0.587, 0.114)); // 感知亮度
	vec4 result = mix(shadow_color, highlight_color, brightness);

	// 保留原始透明度（透明像素不受影響）
	result.a = tex.a;

	COLOR = result;
}
