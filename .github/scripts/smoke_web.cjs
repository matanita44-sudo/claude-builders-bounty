'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

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
let context;
let page;

async function persistEvidence(result, screenshotAlreadyCaptured = false) {
  if (page) {
    try {
      fs.writeFileSync(path.join(evidenceDir, 'infinidive-dom.html'), await page.content());
      if (!screenshotAlreadyCaptured) {
        await page.screenshot({
          path: path.join(evidenceDir, 'infinidive-browser.png'),
          fullPage: true,
        });
      }
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
    context = await browser.newContext({
      viewport: { width: 540, height: 960 },
      hasTouch: true,
      isMobile: true,
      deviceScaleFactor: 1,
    });
    page = await context.newPage();
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

    await page.evaluate(() => {
      const canvas = document.getElementById('canvas');
      globalThis.__infinidiveTouchEvidence = {
        touchstart: 0,
        touchmove: 0,
        touchend: 0,
      };
      for (const eventName of ['touchstart', 'touchmove', 'touchend']) {
        window.addEventListener(eventName, (event) => {
          if (event.target === canvas) {
            globalThis.__infinidiveTouchEvidence[eventName] += 1;
          }
        }, { capture: true, passive: true });
      }
    });

    const beforeInputPath = path.join(evidenceDir, 'infinidive-before-input.png');
    const beforeInput = await page.screenshot({ path: beforeInputPath, fullPage: true });
    await page.touchscreen.tap(270, 842);
    await page.waitForTimeout(1_500);

    const cdp = await context.newCDPSession(page);
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchStart',
      touchPoints: [{ x: 410, y: 700, id: 1, radiusX: 2, radiusY: 2, force: 1 }],
    });
    for (const [x, y] of [[390, 680], [370, 655], [345, 625]]) {
      await cdp.send('Input.dispatchTouchEvent', {
        type: 'touchMove',
        touchPoints: [{ x, y, id: 1, radiusX: 2, radiusY: 2, force: 1 }],
      });
      await page.waitForTimeout(80);
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await page.touchscreen.tap(72, 874);
    await page.waitForTimeout(1_500);

    const postInputRuntime = await page.evaluate(() => {
      const canvas = document.getElementById('canvas');
      const status = document.getElementById('status');
      return {
        canvas_width: canvas?.width ?? 0,
        canvas_height: canvas?.height ?? 0,
        status_hidden: status?.classList.contains('hidden') ?? false,
      };
    });
    if (!postInputRuntime.status_hidden || postInputRuntime.canvas_width < 1 || postInputRuntime.canvas_height < 1) {
      throw new Error(`Godot canvas stopped after synthetic touch input: ${JSON.stringify(postInputRuntime)}`);
    }
    const touchEvents = await page.evaluate(() => globalThis.__infinidiveTouchEvidence);
    if (touchEvents.touchstart < 3 || touchEvents.touchmove < 1 || touchEvents.touchend < 3) {
      throw new Error(`Synthetic touch events did not reach the live canvas: ${JSON.stringify(touchEvents)}`);
    }
    const afterInputPath = path.join(evidenceDir, 'infinidive-browser.png');
    const afterInput = await page.screenshot({
      path: afterInputPath,
      fullPage: true,
    });
    const beforeInputSha256 = crypto.createHash('sha256').update(beforeInput).digest('hex');
    const afterInputSha256 = crypto.createHash('sha256').update(afterInput).digest('hex');
    const retainedBeforeInputSha256 = crypto
      .createHash('sha256')
      .update(fs.readFileSync(beforeInputPath))
      .digest('hex');
    const retainedAfterInputSha256 = crypto
      .createHash('sha256')
      .update(fs.readFileSync(afterInputPath))
      .digest('hex');
    if (retainedBeforeInputSha256 !== beforeInputSha256) {
      throw new Error('The retained pre-input screenshot does not match its recorded SHA-256');
    }
    if (retainedAfterInputSha256 !== afterInputSha256) {
      throw new Error('The retained post-input screenshot does not match its recorded SHA-256');
    }
    if (beforeInputSha256 === afterInputSha256) {
      throw new Error('The rendered page did not change after the synthetic touch sequence');
    }
    if (pageErrors.length || consoleMessages.some((message) => message.type === 'error')) {
      throw new Error('The running page emitted a JavaScript or console error');
    }

    result.status = 'passed';
    result.http_status = response.status();
    result.runtime = runtime;
    result.synthetic_touch = {
      start_tap: { x: 270, y: 842 },
      drag: { from: [410, 700], to: [345, 625] },
      dash_tap: { x: 72, y: 874 },
      post_input_runtime: postInputRuntime,
      canvas_touch_events: touchEvents,
      before_sha256: beforeInputSha256,
      retained_before_sha256: retainedBeforeInputSha256,
      after_sha256: afterInputSha256,
      retained_after_sha256: retainedAfterInputSha256,
      rendered_page_changed: true,
    };
    await persistEvidence(result, true);
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
