/**
 * capture_images.js - §P P2-B: Playwright 視覺參考圖片攔截工具
 * 
 * 用途：從 JS 渲染網站（如 dungeonslasher.wiki）攔截並儲存 PNG/GIF 圖片
 * 使用：node scripts/utils/capture_images.js <URL> [輸出目錄]
 * 
 * 前置需求：
 *   npm install playwright
 *   npx playwright install chromium
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const TARGET_URL = process.argv[2];
  const outDir = process.argv[3] || `${require('os').tmpdir()}\\ds_ref_${Date.now()}`;

  if (!TARGET_URL) {
    console.error('用法：node capture_images.js <URL> [輸出目錄]');
    console.error('範例：node capture_images.js "https://dungeonslasher.wiki/characters" "C:\\Temp\\ds_ref"');
    process.exit(1);
  }

  fs.mkdirSync(outDir, { recursive: true });
  console.log(`[§P P2-B] 目標：${TARGET_URL}`);
  console.log(`[§P P2-B] 輸出：${outDir}`);

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  const captured = [];
  const skipped = [];

  // 攔截所有 image 類型的網路回應
  page.on('response', async (response) => {
    const url = response.url();
    const type = response.request().resourceType();
    
    if (type === 'image') {
      const ext = path.extname(url.split('?')[0]).toLowerCase();
      if (['.gif', '.png', '.jpg', '.jpeg', '.webp'].includes(ext)) {
        try {
          const buffer = await response.body();
          // 過濾掉太小的圖片（通常是 icon/追蹤像素）
          if (buffer.length < 500) {
            skipped.push(`${path.basename(url)} (${buffer.length}B, 太小)`);
            return;
          }
          const filename = `${Date.now()}_${path.basename(url.split('?')[0])}`;
          const savePath = path.join(outDir, filename);
          fs.writeFileSync(savePath, buffer);
          captured.push({ filename, url, size: buffer.length });
          console.log(`[CAPTURED] ${filename} (${(buffer.length / 1024).toFixed(1)}KB) ← ${url}`);
        } catch (e) {
          console.log(`[SKIP] 無法讀取: ${url} - ${e.message}`);
        }
      }
    }
  });

  try {
    await page.goto(TARGET_URL, { waitUntil: 'networkidle', timeout: 45000 });
    // 等待額外的懶加載
    await page.waitForTimeout(3000);
  } catch (e) {
    console.error(`[ERROR] 頁面載入失敗: ${e.message}`);
  }

  await browser.close();

  console.log('\n========== 完成 ==========');
  console.log(`✅ 擷取：${captured.length} 張`);
  console.log(`⏭️  跳過：${skipped.length} 張（太小）`);
  console.log(`📁 輸出目錄：${outDir}`);
  
  if (captured.length > 0) {
    console.log('\n--- 擷取清單 ---');
    captured.forEach(({ filename, size }) => {
      console.log(`  ${filename} (${(size / 1024).toFixed(1)}KB)`);
    });
  }
})();
