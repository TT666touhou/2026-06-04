/**
 * capture_ds_official.js - Dungeon Slasher 官方視覺資源捕獲腳本
 * 只抓取官方來源：Fandom Wiki、NamuWiki、Steam
 * §P P2-B 執行腳本
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

const OUT_DIR = 'D:\\2026-06-04\\assets\\characters\\ds_reference';
const REPORT = [];

// 確保輸出目錄存在
fs.mkdirSync(OUT_DIR, { recursive: true });

function downloadFile(url, filename) {
  return new Promise((resolve, reject) => {
    const filePath = path.join(OUT_DIR, filename);
    const protocol = url.startsWith('https') ? https : http;
    const file = fs.createWriteStream(filePath);
    
    const options = {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }
    };
    
    protocol.get(url, options, (response) => {
      if (response.statusCode === 301 || response.statusCode === 302) {
        file.close();
        fs.unlinkSync(filePath);
        downloadFile(response.headers.location, filename).then(resolve).catch(reject);
        return;
      }
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        const size = fs.statSync(filePath).size;
        if (size < 1000) {
          fs.unlinkSync(filePath);
          resolve(null);
        } else {
          console.log(`[SAVED] ${filename} (${Math.round(size/1024)}KB)`);
          resolve(filePath);
        }
      });
    }).on('error', (err) => {
      file.close();
      if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
      reject(err);
    });
  });
}

async function capturePageImages(page, url, prefix, waitFor = 'networkidle') {
  const captured = [];
  
  page.on('response', async (response) => {
    const respUrl = response.url();
    const type = response.request().resourceType();
    
    if (type === 'image') {
      const ext = path.extname(respUrl.split('?')[0]).toLowerCase();
      if (['.gif', '.png', '.jpg', '.jpeg', '.webp'].includes(ext)) {
        try {
          const buffer = await response.body();
          if (buffer.length > 2000) {  // 過濾小圖
            const fname = `${prefix}_${Date.now()}_${path.basename(respUrl.split('?')[0])}`.slice(0, 100);
            const savePath = path.join(OUT_DIR, fname);
            fs.writeFileSync(savePath, buffer);
            captured.push({ fname, size: buffer.length, url: respUrl });
            console.log(`[INTERCEPTED] ${ext.toUpperCase()} ${fname} (${Math.round(buffer.length/1024)}KB)`);
          }
        } catch (e) {}
      }
    }
  });
  
  try {
    await page.goto(url, { waitUntil: waitFor, timeout: 45000 });
    await page.waitForTimeout(4000);
  } catch (e) {
    console.log(`[WARN] ${url}: ${e.message.slice(0, 80)}`);
  }
  
  return captured;
}

async function main() {
  console.log('=== Dungeon Slasher 官方資源捕獲 ===');
  console.log('官方來源：Fandom Wiki + NamuWiki + Steam');
  console.log(`輸出目錄：${OUT_DIR}`);
  
  const browser = await chromium.launch({ 
    headless: true,
    args: ['--disable-blink-features=AutomationControlled']
  });
  
  // =====================================================
  // 來源 1: Fandom Wiki - 主頁面
  // =====================================================
  console.log('\n[1/4] Fandom Wiki - 主頁面...');
  const page1 = await browser.newPage();
  await page1.setExtraHTTPHeaders({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0'
  });
  const fandomMain = await capturePageImages(page1, 
    'https://dungeonslasher.fandom.com/wiki/Dungeon_Slasher_Wiki',
    'fandom_main', 'load');
  await page1.close();
  REPORT.push({ source: 'Fandom Wiki Main', captured: fandomMain.length });
  
  // =====================================================
  // 來源 2: Fandom Wiki - 角色頁面
  // =====================================================
  console.log('\n[2/4] Fandom Wiki - 角色頁面...');
  const page2 = await browser.newPage();
  await page2.setExtraHTTPHeaders({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
  });
  const fandomChars = await capturePageImages(page2,
    'https://dungeonslasher.fandom.com/wiki/Playable_Characters',
    'fandom_chars', 'load');
  await page2.close();
  REPORT.push({ source: 'Fandom Wiki Characters', captured: fandomChars.length });

  // =====================================================
  // 來源 3: NamuWiki - Dungeon Slasher 頁面
  // =====================================================
  console.log('\n[3/4] NamuWiki...');
  const page3 = await browser.newPage();
  await page3.setExtraHTTPHeaders({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0'
  });
  // NamuWiki 的 URL 編碼
  const namuCaptured = await capturePageImages(page3,
    'https://namu.wiki/w/%EB%8D%98%EC%A0%84%20%EC%8A%AC%EB%9E%98%EC%85%94',
    'namu_ds', 'domcontentloaded');
  await page3.close();
  REPORT.push({ source: 'NamuWiki DS', captured: namuCaptured.length });

  // =====================================================
  // 來源 4: Steam 官方頁面（用 Playwright 確保 JS 渲染）
  // =====================================================
  console.log('\n[4/4] Steam 官方頁面...');
  const page4 = await browser.newPage();
  await page4.setExtraHTTPHeaders({
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0'
  });
  const steamCaptured = await capturePageImages(page4,
    'https://store.steampowered.com/app/2712460/DUNGEON_SLASHER/',
    'steam_page', 'load');
  await page4.close();
  REPORT.push({ source: 'Steam Page', captured: steamCaptured.length });

  await browser.close();

  // =====================================================
  // 最終報告
  // =====================================================
  console.log('\n=== 捕獲報告 ===');
  REPORT.forEach(r => {
    console.log(`  ${r.source}: ${r.captured} 張`);
  });
  
  const allFiles = fs.readdirSync(OUT_DIR);
  const gifs = allFiles.filter(f => f.toLowerCase().endsWith('.gif'));
  const imgs = allFiles.filter(f => !f.toLowerCase().endsWith('.gif'));
  
  console.log(`\n總計: ${allFiles.length} 個檔案`);
  console.log(`  GIF: ${gifs.length} 個`);
  console.log(`  圖片: ${imgs.length} 個`);
  console.log('\nGIF 列表:');
  gifs.forEach(g => {
    const size = fs.statSync(path.join(OUT_DIR, g)).size;
    console.log(`  ${g} (${Math.round(size/1024)}KB)`);
  });
}

main().catch(console.error);
