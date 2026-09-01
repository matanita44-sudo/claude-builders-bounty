'use strict';

const fs = require('node:fs');
const path = require('node:path');

const targetUrl = process.argv[2];
const evidenceDir = process.argv[3];
const chromeBin = process.env.INFINIDIVE_CHROME_BIN;
const playwrightRoot = process.env.INFINIDIVE_PLAYWRIGHT_ROOT;

if (!targetUrl || !evidenceDir || !chromeBin || !playwrightRoot) {
  throw new Error('Web smoke requires URL, evidence directory, Chrome, and Playwright root');
}

const { chromium } = require(path.join(playwrightRoot, 'node_modules', 'playwright-core'));
fs.mkdirSync(evidenceDir, { recursive: true });

const consoleMessages = [];
const pageErrors = [];
let browser;
let page;

async function persistEvidence(result) {
  if (page) {
    try {
      fs.writeFileSync(path.join(evidenceDir, 'infinidive-dom.html'), await page.content());
      await page.screenshot({
        path: path.join(evidenceDir, 'infinidive-browser.png'),
        fullPage: true,
      });
    } catch (error) {
      result.evidence_error = String(error);
    }
  }
  fs.writeFileSync(
    path.join(evidenceDir, 'infinidive-browser.json'),
    `${JSON.stringify(result, null, 2)}\n`,
  );
}

(async () => {
  const result = {
    url: targetUrl,
    status: 'failed',
    console_messages: consoleMessages,
    page_errors: pageErrors,
  };

  try {
    browser = await chromium.launch({
      executablePath: chromeBin,
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--use-angle=swiftshader',
        '--enable-unsafe-swiftshader',
        '--autoplay-policy=no-user-gesture-required',
      ],
    });
    page = await browser.newPage({ viewport: { width: 540, height: 960 } });
    page.on('console', (message) => {
      consoleMessages.push({ type: message.type(), text: message.text() });
    });
    page.on('pageerror', (error) => pageErrors.push(String(error)));

    const response = await page.goto(targetUrl, {
      waitUntil: 'domcontentloaded',
      timeout: 30_000,
    });
    if (!response || !response.ok()) {
      throw new Error(`Web entry returned HTTP ${response ? response.status() : 'no response'}`);
    }

    await page.waitForFunction(
      () => document.getElementById('status')?.classList.contains('hidden') === true,
      null,
      { timeout: 90_000 },
    );

    const runtime = await page.evaluate(() => {
      const canvas = document.getElementById('canvas');
      const status = document.getElementById('status');
      return {
        canvas_width: canvas?.width ?? 0,
        canvas_height: canvas?.height ?? 0,
        status_hidden: status?.classList.contains('hidden') ?? false,
        status_text: status?.textContent ?? '',
      };
    });
    if (!runtime.status_hidden || runtime.canvas_width < 1 || runtime.canvas_height < 1) {
      throw new Error(`Godot canvas is not running: ${JSON.stringify(runtime)}`);
    }
    if (pageErrors.length || consoleMessages.some((message) => message.type === 'error')) {
      throw new Error('The running page emitted a JavaScript or console error');
    }

    result.status = 'passed';
    result.http_status = response.status();
    result.runtime = runtime;
    await persistEvidence(result);
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } catch (error) {
    result.failure = String(error);
    await persistEvidence(result);
    process.stderr.write(`${JSON.stringify(result, null, 2)}\n`);
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close();
  }
})();
