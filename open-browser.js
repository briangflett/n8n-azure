const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.goto('https://example.com');

  console.log('Browser window opened. Press Ctrl+C to close.');

  // Keep the browser open
  await new Promise(() => {});
})();
