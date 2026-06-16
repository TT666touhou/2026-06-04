/**
 * capture_ds_wiki.js — 從 dungeonslasher.wiki 抓取真實角色 GIF 和 Sprite
 * 
 * 策略：
 * 1. 先取 /data/characters.json 取得角色清單
 * 2. 用 Playwright 以 Chromium 實際瀏覽每個角色頁面，攔截 /res/ 路徑的圖片請求
 * 3. 只保存來自 dungeonslasher.wiki/res/ 路徑的圖片（確保是官方內容）
 * 
 * 使用：node scripts/utils/capture_ds_wiki.js
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const https = require('https');

const BASE_URL    = 'https://dungeonslasher.wiki';
const DATA_URL    = `${BASE_URL}/data/characters.json`;
const OUT_BASE    = 'D:\\2026-06-04\\assets\\characters\\ds_reference';
const GIF_DIR     = path.join(OUT_BASE, 'wiki_gifs');
const SPRITE_DIR  = path.join(OUT_BASE, 'wiki_sprites');
const SKIN_DIR    = path.join(OUT_BASE, 'wiki_skins');

// ✅ 只接受來自 dungeonslasher.wiki/res/ 的官方圖片
const VALID_IMG_PREFIX = `${BASE_URL}/res/`;

fs.mkdirSync(GIF_DIR,    { recursive: true });
fs.mkdirSync(SPRITE_DIR, { recursive: true });
fs.mkdirSync(SKIN_DIR,   { recursive: true });

const saved = { gifs: [], sprites: [], skins: [] };

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, {
      headers: { 'User-Agent': 'Mozilla/5.0' }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(JSON.parse(data)));
    }).on('error', reject);
  });
}

async function captureCharacterPage(browser, charName, charFolder) {
  const page = await browser.newPage();
  const charUrl = `${BASE_URL}/characters/${charFolder}`;
  const captured = { gifs: [], sprites: [], skins: [] };

  // ✅ 攔截器：只接受 /res/characters/ 路徑的圖片
  page.on('response', async (response) => {
    const url = response.url();
    if (!url.startsWith(VALID_IMG_PREFIX)) return;  // 嚴格過濾

    const type = response.request().resourceType();
    if (type !== 'image') return;

    const urlPath = url.replace(BASE_URL, '');
    const ext = path.extname(url.split('?')[0]).toLowerCase();
    
    if (!['.gif', '.png', '.jpg', '.webp'].includes(ext)) return;

    try {
      const buffer = await response.body();
      if (buffer.length < 500) return;  // 過濾空圖

      const fname = `${charName.replace(/\s+/g, '_')}_${path.basename(url.split('?')[0]).replace(/\s+/g, '_')}`;
      
      let outPath;
      if (ext === '.gif') {
        outPath = path.join(GIF_DIR, fname);
        captured.gifs.push(fname);
      } else if (url.includes('/sprite.')) {
        outPath = path.join(SPRITE_DIR, fname);
        captured.sprites.push(fname);
      } else {
        outPath = path.join(SKIN_DIR, fname);
        captured.skins.push(fname);
      }

      if (!fs.existsSync(outPath)) {
        fs.writeFileSync(outPath, buffer);
        const kb = Math.round(buffer.length / 1024);
        const tag = ext === '.gif' ? '[GIF✓]' : '[IMG]';
        console.log(`    ${tag} ${fname} (${kb}KB) — ${url.replace(BASE_URL, '')}`);
      }
    } catch (e) {}
  });

  try {
    await page.goto(charUrl, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(3000);  // 等 JS 渲染完成
  } catch (e) {
    console.log(`  [WARN] ${charName}: ${e.message.slice(0, 60)}`);
  }

  await page.close();
  return captured;
}

async function main() {
  console.log('=== dungeonslasher.wiki 官方圖片擷取 ===');
  console.log(`✅ 嚴格限制：只抓取 ${VALID_IMG_PREFIX} 路徑的圖片`);

  // 取得角色清單
  const charsData = await fetchJson(DATA_URL);
  const chars = charsData.data;
  console.log(`找到 ${chars.length} 個角色\n`);

  const browser = await chromium.launch({
    headless: true,
    args: ['--disable-blink-features=AutomationControlled', '--no-sandbox']
  });

  // 先抓主頁，觸發 CDN 預熱
  const mainPage = await browser.newPage();
  try { await mainPage.goto(BASE_URL, { waitUntil: 'load', timeout: 20000 }); } catch (e) {}
  await mainPage.close();

  // 對每個角色抓取
  for (const char of chars) {
    console.log(`\n[${char.name}] → /characters/${char.folder}`);
    const result = await captureCharacterPage(browser, char.name, char.folder);
    saved.gifs.push(...result.gifs);
    saved.sprites.push(...result.sprites);
    saved.skins.push(...result.skins);
  }

  // 也抓主頁的角色展示圖
  console.log('\n[主頁] 角色展示...');
  const homePage = await browser.newPage();
  const homeCaptures = [];
  homePage.on('response', async (response) => {
    const url = response.url();
    if (!url.startsWith(VALID_IMG_PREFIX)) return;
    const type = response.request().resourceType();
    if (type !== 'image') return;
    try {
      const buffer = await response.body();
      if (buffer.length < 1000) return;
      const fname = `home_${path.basename(url.split('?')[0]).replace(/\s+/g, '_')}`;
      const ext = path.extname(fname).toLowerCase();
      const outDir = ext === '.gif' ? GIF_DIR : SPRITE_DIR;
      const outPath = path.join(outDir, fname);
      if (!fs.existsSync(outPath)) {
        fs.writeFileSync(outPath, buffer);
        homeCaptures.push(fname);
        console.log(`  [HOME] ${fname} (${Math.round(buffer.length/1024)}KB)`);
      }
    } catch (e) {}
  });
  try {
    await homePage.goto(BASE_URL, { waitUntil: 'networkidle', timeout: 30000 });
    await homePage.waitForTimeout(5000);
  } catch (e) {}
  await homePage.close();

  await browser.close();

  // 最終報告
  console.log('\n=================================================');
  console.log('=== 擷取完成報告 ===');
  console.log(`GIF: ${saved.gifs.length} 個`);
  console.log(`Sprites: ${saved.sprites.length} 個`);
  console.log(`Skins: ${saved.skins.length} 個`);
  
  const allGifs = fs.readdirSync(GIF_DIR).filter(f => f.endsWith('.gif'));
  const allSprites = fs.readdirSync(SPRITE_DIR);
  console.log(`\nwiki_gifs/ 目錄 (${allGifs.length} GIFs):`);
  allGifs.forEach(g => {
    const size = fs.statSync(path.join(GIF_DIR, g)).size;
    console.log(`  ${g} (${Math.round(size/1024)}KB)`);
  });
  console.log(`\nwiki_sprites/ 目錄 (${allSprites.length} 個):`);
  allSprites.slice(0, 10).forEach(s => {
    const size = fs.statSync(path.join(SPRITE_DIR, s)).size;
    console.log(`  ${s} (${Math.round(size/1024)}KB)`);
  });
}

main().catch(console.error);
