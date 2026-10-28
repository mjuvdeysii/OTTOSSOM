const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
  for (const f of process.argv.slice(2)) {
    await p.setContent(`<html><body style="margin:0">${fs.readFileSync(f, 'utf8')}</body></html>`);
    await p.screenshot({ path: f.replace('.svg', '.png'), clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  }
  await b.close();
})();
