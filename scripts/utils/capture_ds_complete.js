/**
 * capture_ds_complete.js — Dungeon Slasher 完整官方素材擷取腳本
 * 
 * 功能：
 * 1. 從 dungeonslasher.wiki 下載所有角色的 Skins 頁面圖片
 * 2. 按角色建立分類資料夾
 * 3. 過濾背景/UI 圖片（只保留角色皮膚）
 * 4. 刪除重複圖片（相同 URL/檔名只保留一份）
 * 
 * 使用：node scripts/utils/capture_ds_complete.js [角色名] 或不帶參數處理全部
 * 
 * 官方來源規則（§P-0 白名單）：
 * - 只接受 https://dungeonslasher.wiki/res/characters/ 路徑的圖片（角色相關）
 * - 排除 /res/ui/ /res/mascot/ /res/bosses/ 等非皮膚路徑
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const https = require('https');
const crypto = require('crypto');

// ============================================================
// 設定
// ============================================================
const BASE_URL   = 'https://dungeonslasher.wiki';
const DATA_URL   = `${BASE_URL}/data/characters.json`;
const OUT_BASE   = 'D:\\2026-06-04\\assets\\characters\\ds_reference\\by_character';

// ✅ 允許的圖片 URL 前綴（只接受角色相關路徑）
const CHAR_IMG_PREFIX = `${BASE_URL}/res/characters/`;

// ❌ 排除關鍵詞（UI、背景、非角色素材）
const EXCLUDE_KEYWORDS = [
  '/res/ui/', '/res/mascot/', '/res/bosses/', '/res/artifacts/',
  '/res/weapons/', '/res/skills/', '/res/perks/', '/res/items/',
  'background', 'DS-logo', 'loading', 'version_icon', 'spinner',
  'favicon', 'icon', 'logo', 'bg.png', 'bg.jpg'
];

const savedHashes = new Set(); // 用於去重的 MD5 集合

// ============================================================
// 工具函式
// ============================================================
function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => resolve(JSON.parse(data)));
    }).on('error', reject);
  });
}

function isValidCharImg(url) {
  if (!url.startsWith(CHAR_IMG_PREFIX)) return false;
  for (const kw of EXCLUDE_KEYWORDS) {
    if (url.includes(kw)) return false;
  }
  return true;
}

function getFileMd5(buf) {
  return crypto.createHash('md5').update(buf).digest('hex');
}

function sanitizeName(name) {
  return name.replace(/[^\w\-_\.]/g, '_');
}

async function captureCharSkins(browser, charName, charFolder, targetPage = 'Skins') {
  const charDir = path.join(OUT_BASE, sanitizeName(charName));
  const skinsDir = path.join(charDir, 'skins');
  const gifDir   = path.join(charDir, 'gifs');
  fs.mkdirSync(skinsDir, { recursive: true });
  fs.mkdirSync(gifDir,   { recursive: true });

  const pageUrl = `${BASE_URL}/player?character=${charFolder}&page=${targetPage}`;
  const page = await browser.newPage();
  const captured = { skins: 0, gifs: 0, dupes: 0, excluded: 0 };

  page.on('response', async (response) => {
    const url = response.url();
    const type = response.request().resourceType();
    if (type !== 'image') return;

    // ✅ 必須是 /res/characters/ 路徑
    if (!isValidCharImg(url)) {
      if (url.includes('/res/') && !url.includes('/res/characters/')) {
        captured.excluded++;
      }
      return;
    }

    const ext = path.extname(url.split('?')[0]).toLowerCase();
    if (!['.gif', '.png', '.jpg', '.webp'].includes(ext)) return;

    try {
      const buf = await response.body();
      if (buf.length < 200) return; // 過濾空圖

      // 去重檢查
      const hash = getFileMd5(buf);
      if (savedHashes.has(hash)) {
        captured.dupes++;
        return;
      }
      savedHashes.add(hash);

      // 從 URL 提取皮膚名稱
      const urlPath = decodeURIComponent(url.replace(BASE_URL, ''));
      const fname = sanitizeName(path.basename(urlPath.split('?')[0]));

      let outPath;
      if (ext === '.gif') {
        outPath = path.join(gifDir, fname);
        captured.gifs++;
      } else {
        outPath = path.join(skinsDir, fname);
        captured.skins++;
      }

      if (!fs.existsSync(outPath)) {
        fs.writeFileSync(outPath, buf);
        const kb = Math.round(buf.length / 1024);
        const tag = ext === '.gif' ? '[GIF]' : '[PNG]';
        console.log(`    ${tag} ${fname} (${kb}KB)`);
      }
    } catch (e) {}
  });

  try {
    await page.goto(pageUrl, { waitUntil: 'networkidle', timeout: 45000 });
    await page.waitForTimeout(3000);

    // 嘗試滾動以觸發懶加載
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(2000);
  } catch (e) {
    console.log(`  [WARN] ${charName}/${targetPage}: ${e.message.slice(0, 60)}`);
  }

  await page.close();
  return captured;
}

async function captureCharIllustrations(browser, charName, charFolder) {
  // 也抓 Illustrations 頁面
  const charDir = path.join(OUT_BASE, sanitizeName(charName));
  const illusDir = path.join(charDir, 'illustrations');
  fs.mkdirSync(illusDir, { recursive: true });

  const pageUrl = `${BASE_URL}/player?character=${charFolder}&page=Illustrations`;
  const page = await browser.newPage();
  const captured = { imgs: 0, gifs: 0, dupes: 0 };

  page.on('response', async (response) => {
    const url = response.url();
    const type = response.request().resourceType();
    if (type !== 'image') return;
    if (!isValidCharImg(url)) return;

    const ext = path.extname(url.split('?')[0]).toLowerCase();
    if (!['.gif', '.png', '.jpg', '.webp'].includes(ext)) return;

    try {
      const buf = await response.body();
      if (buf.length < 200) return;

      const hash = getFileMd5(buf);
      if (savedHashes.has(hash)) {
        captured.dupes++;
        return;
      }
      savedHashes.add(hash);

      const fname = sanitizeName(path.basename(decodeURIComponent(url.split('?')[0])));
      const outPath = path.join(illusDir, fname);
      if (!fs.existsSync(outPath)) {
        fs.writeFileSync(outPath, buf);
        const kb = Math.round(buf.length / 1024);
        console.log(`    [ILLUS] ${fname} (${kb}KB)`);
        ext === '.gif' ? captured.gifs++ : captured.imgs++;
      }
    } catch (e) {}
  });

  try {
    await page.goto(pageUrl, { waitUntil: 'networkidle', timeout: 45000 });
    await page.waitForTimeout(3000);
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(2000);
  } catch (e) {}

  await page.close();
  return captured;
}

// ============================================================
// 主程式
// ============================================================
async function main() {
  const targetChar = process.argv[2]; // 可選：指定角色名

  console.log('=== Dungeon Slasher 完整素材擷取 ===');
  console.log(`✅ 來源白名單：${CHAR_IMG_PREFIX}`);
  console.log(`❌ 排除關鍵詞：${EXCLUDE_KEYWORDS.slice(0, 5).join(', ')} 等`);
  if (targetChar) console.log(`🎯 只處理角色：${targetChar}`);
  console.log('');

  const charsData = await fetchJson(DATA_URL);
  let chars = charsData.data;
  if (targetChar) {
    chars = chars.filter(c => c.name.toLowerCase() === targetChar.toLowerCase() || c.folder === targetChar.toLowerCase());
  }
  console.log(`處理 ${chars.length} 個角色...\n`);

  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-blink-features=AutomationControlled']
  });

  const summary = [];

  for (const char of chars) {
    console.log(`\n━━━ [${char.name}] (${char.folder}) ━━━`);

    // 1. Skins 頁面
    console.log(`  → Skins 頁面...`);
    const skins = await captureCharSkins(browser, char.name, char.folder, 'Skins');

    // 2. Illustrations 頁面（有動畫 GIF）
    console.log(`  → Illustrations 頁面...`);
    const illus = await captureCharIllustrations(browser, char.name, char.folder);

    // 3. Overview 頁面（主要 Sprite）
    console.log(`  → Overview 頁面...`);
    const overview = await captureCharSkins(browser, char.name, char.folder, 'Overview');

    const total = skins.skins + skins.gifs + illus.imgs + illus.gifs + overview.skins + overview.gifs;
    const dupes  = skins.dupes + illus.dupes + overview.dupes;
    console.log(`  ✓ 完成: ${total} 個新圖 | 去重: ${dupes} 個 | 排除 UI: ${skins.excluded} 個`);

    summary.push({
      name: char.name,
      folder: char.folder,
      skins: skins.skins,
      gifs: skins.gifs + illus.gifs + overview.gifs,
      illus: illus.imgs,
      dupes: dupes,
      total: total
    });

    // 冷卻避免觸發 rate limit
    await new Promise(r => setTimeout(r, 1500));
  }

  await browser.close();

  // ============================================================
  // 最終報告
  // ============================================================
  console.log('\n\n=== 擷取完成報告 ===');
  console.log('角色名             | 皮膚 | GIF | 插畫 | 去重 | 合計');
  console.log('-------------------|------|-----|------|------|-----');
  let totalAll = 0;
  for (const s of summary) {
    const name = s.name.padEnd(18);
    console.log(`${name} | ${String(s.skins).padStart(4)} | ${String(s.gifs).padStart(3)} | ${String(s.illus).padStart(4)} | ${String(s.dupes).padStart(4)} | ${s.total}`);
    totalAll += s.total;
  }
  console.log(`${'合計'.padEnd(18)} |      |     |      |      | ${totalAll}`);

  // 顯示目錄結構
  console.log('\n=== 輸出目錄結構 ===');
  console.log(`${OUT_BASE}`);
  const charDirs = fs.readdirSync(OUT_BASE).filter(d => fs.statSync(path.join(OUT_BASE, d)).isDirectory());
  for (const d of charDirs) {
    const subDirs = fs.readdirSync(path.join(OUT_BASE, d));
    const totalFiles = subDirs.reduce((sum, sub) => {
      const subPath = path.join(OUT_BASE, d, sub);
      if (fs.statSync(subPath).isDirectory()) {
        return sum + fs.readdirSync(subPath).length;
      }
      return sum + 1;
    }, 0);
    console.log(`  ├── ${d}/ (${totalFiles} 個檔案)`);
  }
}

main().catch(console.error);
