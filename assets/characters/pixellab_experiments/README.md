# PixelLab Experiment Characters
> Generated: 2026-06-15 | Designer Role | §O-REF Maintained

## Generated Files

| File | Size | Style | Description |
|------|------|-------|-------------|
| `1A_16x16_RPG.png` | 16×16 | RPG Anime | 雙馬尾少女，復古 RPG 風格，最小尺寸 |
| `1B_32x32_RPG.png` | 32×32 | RPG Anime | 雙馬尾少女，復古 RPG 風格，標準尺寸 |
| `1C_32x48_DS.png` | 32×48 | Dungeon Slasher | 2.5頭身 chibi，Dungeon Slasher 比例 |
| `2A_16x16_MR.png` | 16×16 | MRMOTEXT 1-bit | 積木簡式風格，最小尺寸 |
| `2B_32x32_MR.png` | 32×32 | MRMOTEXT 1-bit | 積木簡式風格，標準尺寸 |
| `2C_32x48_MR_DS.png` | 32×48 | MRMOTEXT × DS | 1-bit 積木感 + Dungeon Slasher chibi 比例 |

## Common Constraints Applied
- VfxMix 34-color palette (described in prompt text, v2 pixen has no color_palette param)
- `outline: "lineless"` (no border)
- `view: "side"`, `direction: "south"`
- `no_background: true`
- API: `POST https://api.pixellab.ai/v2/create-image-pixen`

## Account Status
- Plan: Tier 1: Pixel Apprentice (2000 generations/month)
- Remaining after this batch: ~1990

## Notes (v2 API Discovered Parameters)
- `outline` enum: `"single color black outline"`, `"single color outline"`, `"selective outline"`, `"lineless"`
- `detail` enum: `"low detail"`, `"medium detail"`, `"highly detailed"`
- `view` enum: `"side"`, `"low top-down"`, `"high top-down"`
- `direction` enum: `"north"`, `"north-east"`, `"east"`, `"south-east"`, `"south"`, `"south-west"`, `"west"`, `"north-west"`
- `color_palette` is NOT supported in v2 pixen (v1 only)
- Image size must be divisible by 4, min 16px, max 768px