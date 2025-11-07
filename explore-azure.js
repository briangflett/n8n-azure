const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: false,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--start-maximized'],
    defaultViewport: null
  });

  const page = await browser.newPage();

  console.log('Opening Azure Portal...');
  await page.goto('https://portal.azure.com', { waitUntil: 'networkidle2' });

  // Wait for user to login if needed
  console.log('Please login if prompted...');
  await new Promise(resolve => setTimeout(resolve, 5000));

  // Navigate to resource groups
  console.log('Navigating to resource groups...');
  await page.goto('https://portal.azure.com/#browse/resourcegroups', { waitUntil: 'networkidle2' });
  await new Promise(resolve => setTimeout(resolve, 3000));

  // Try to find mas-n8n-rg resource group
  console.log('Looking for mas-n8n-rg resource group...');

  // Wait for the resource group list to load
  await new Promise(resolve => setTimeout(resolve, 5000));

  // Take screenshot
  await page.screenshot({ path: 'azure-resource-groups.png', fullPage: true });
  console.log('Screenshot saved: azure-resource-groups.png');

  // Try to click on mas-n8n-rg if it exists
  try {
    const rgSelector = 'a[title*="mas-n8n-rg"], a:has-text("mas-n8n-rg"), [aria-label*="mas-n8n-rg"]';
    await page.waitForSelector('text=mas-n8n-rg', { timeout: 5000 });
    await page.click('text=mas-n8n-rg');

    console.log('Opened mas-n8n-rg resource group');
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Take screenshot of the resource group
    await page.screenshot({ path: 'azure-mas-n8n-rg.png', fullPage: true });
    console.log('Screenshot saved: azure-mas-n8n-rg.png');

  } catch (error) {
    console.log('Could not find mas-n8n-rg automatically');
  }

  console.log('\nBrowser ready for exploration. Press Ctrl+C when done.');

  // Keep browser open
  await new Promise(() => {});
})();
