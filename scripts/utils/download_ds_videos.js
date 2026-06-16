/**
 * download_ds_videos.js — 從官方 YouTube 頻道下載 DS 影片幀
 * 
 * 官方頻道：https://www.youtube.com/channel/UCEmLz43Im9YyD92cVJbUWMg
 * 
 * 規則（§P-0）：
 * - 只下載標題包含 "Dungeon Slasher" 的影片
 * - 排除 free fire、其他遊戲相關影片
 * - 優先抓取 GIF（角色動作展示片段）
 * 
 * 使用：node scripts/utils/download_ds_videos.js
 */

const { execSync, exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const FFMPEG = 'C:\\Users\\88698\\AppData\\Local\\Microsoft\\WinGet\\Packages\\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\\ffmpeg-8.1.1-full_build\\bin\\ffmpeg.exe';
const YTDLP = 'yt-dlp';
const OUT_BASE = 'D:\\2026-06-04\\assets\\characters\\ds_reference\\videos';
const FRAME_DIR = path.join(OUT_BASE, 'frames');
const GIF_DIR   = path.join(OUT_BASE, 'action_gifs');

fs.mkdirSync(FRAME_DIR, { recursive: true });
fs.mkdirSync(GIF_DIR,   { recursive: true });

// ✅ 確認是 DS 影片的白名單關鍵詞（標題必須包含）
const DS_KEYWORDS = ['dungeon slasher', 'dungeonslasher'];

// ✅ 已知的官方 DS 影片 ID（直接列表，最可靠）
const KNOWN_DS_VIDEOS = [
  { id: 'BcH2rUgHc5s', title: 'Dungeon Slasher Trailer',          priority: 1 },
  { id: 'A8ths_-tkmA', title: 'DS Character Showcase (30s)',       priority: 1 },
  { id: 'SNLp3HsSfoM', title: 'Dungeon Slasher_15s_Guardian',      priority: 2 },
  { id: '0vx5ypPhfVw', title: 'Dungeon Slasher_15s_Skill',         priority: 2 },
  { id: 'XFgRwUVjiqU', title: 'Dungeon Slasher_15s_Boss',          priority: 2 },
  { id: '8RWdykP-hzs', title: 'Dungeon Slasher_15s_We',            priority: 2 },
  { id: 'U4Y1pGZuNF8', title: 'Dungeon Slasher Action Roguelike',  priority: 2 },
  { id: 'Utb2rUgHc5s', title: 'DS JP Trailer',                     priority: 3 },
  { id: 'UtRFbks3XtM', title: 'DS Unknown (short)',                 priority: 3 },
  { id: '-8v0qC34mF0', title: 'DS Action Short',                   priority: 3 },
  { id: 'rQXH8wkCF8s', title: 'DS Short 2',                        priority: 3 },
  { id: '-uiUbcUJnkg', title: 'DS Short 3',                        priority: 3 },
  { id: 'f-0HyPtnIZE', title: 'DS Short 4',                        priority: 3 },
  { id: '18dNb3uh5Yg', title: 'DS Shaman Short',                   priority: 3 },
  { id: 'CXHJWIslWkg', title: 'DS Short 5',                        priority: 3 },
];

function runCmd(cmd, timeout = 120000) {
  try {
    return execSync(cmd, { timeout, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  } catch (e) {
    return e.stdout || '';
  }
}

async function downloadVideoFrames(videoId, title, priorityLevel) {
  const safeTitle = title.replace(/[^\w\s-]/g, '').replace(/\s+/g, '_').slice(0, 40);
  const videoDir  = path.join(OUT_BASE, `${safeTitle}_${videoId}`);
  fs.mkdirSync(videoDir, { recursive: true });

  const videoUrl = `https://www.youtube.com/watch?v=${videoId}`;
  console.log(`  📥 下載: ${title} (${videoId})`);

  // Step 1: 取得最佳格式的串流 URL
  let streamUrl = '';
  try {
    const result = runCmd(
      `${YTDLP} -f "best[height<=480]" --get-url "${videoUrl}" 2>nul`,
      30000
    );
    streamUrl = result.trim().split('\n')[0];
  } catch (e) {
    console.log(`    [WARN] 無法取得串流 URL`);
    return null;
  }

  if (!streamUrl || streamUrl.length < 10) {
    console.log(`    [SKIP] 無有效串流 URL`);
    return null;
  }

  // Step 2: 用 ffmpeg 每秒擷取 2 幀
  const framePath = path.join(videoDir, 'frame_%03d.jpg');
  console.log(`    → 擷取幀...`);
  runCmd(`"${FFMPEG}" -i "${streamUrl}" -vf "fps=2" -q:v 2 "${framePath}" -y`, 60000);

  const frames = fs.readdirSync(videoDir).filter(f => f.endsWith('.jpg'));
  console.log(`    ✓ ${frames.length} 幀`);

  // Step 3: 生成 GIF（取前 30 幀，最多 15 秒）
  if (frames.length >= 4) {
    const gifPath = path.join(GIF_DIR, `${safeTitle}.gif`);
    const frameCnt = Math.min(frames.length, 30);
    runCmd(
      `"${FFMPEG}" -i "${path.join(videoDir, 'frame_%03d.jpg')}" -vframes ${frameCnt} ` +
      `-vf "fps=10,scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" ` +
      `"${gifPath}" -y`,
      60000
    );

    if (fs.existsSync(gifPath)) {
      const size = Math.round(fs.statSync(gifPath).size / 1024);
      console.log(`    ✓ GIF: ${path.basename(gifPath)} (${size}KB)`);
    }
  }

  return { videoId, frames: frames.length };
}

async function main() {
  console.log('=== Dungeon Slasher 官方影片幀擷取 ===');
  console.log(`✅ 只處理白名單中的已知 DS 影片 (${KNOWN_DS_VIDEOS.length} 個)`);
  console.log(`❌ 排除所有非 DS 標題影片（free fire 等）\n`);

  const results = [];

  // 優先處理 P1 影片（完整 Trailer）
  const sorted = KNOWN_DS_VIDEOS.sort((a, b) => a.priority - b.priority);

  for (const video of sorted) {
    const result = await downloadVideoFrames(video.id, video.title, video.priority);
    if (result) results.push(result);
    await new Promise(r => setTimeout(r, 1000)); // 冷卻
  }

  console.log('\n=== 影片下載報告 ===');
  results.forEach(r => console.log(`  ${r.videoId}: ${r.frames} 幀`));

  console.log('\n=== 生成的 GIF ===');
  const gifs = fs.readdirSync(GIF_DIR).filter(f => f.endsWith('.gif'));
  gifs.forEach(g => {
    const size = Math.round(fs.statSync(path.join(GIF_DIR, g)).size / 1024);
    console.log(`  ${g} (${size}KB)`);
  });
}

main().catch(console.error);
