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

const qaUrl = new URL(targetUrl);
qaUrl.searchParams.set('infinidive_qa', '1');
const criticalAssetRoot = qaUrl.pathname.endsWith('/')
  ? qaUrl.pathname
  : `${qaUrl.pathname.slice(0, qaUrl.pathname.lastIndexOf('/') + 1)}`;

const consoleMessages = [];
const pageErrors = [];
const pageCrashes = [];
const requestFailures = [];
const criticalSubresourceNon2xx = [];
const criticalSubresourceErrors = [];
let browser;
let context;
let page;

function isCriticalGameSubresource(request) {
  if (!request || request.isNavigationRequest()) return false;
  let requestUrl;
  try {
    requestUrl = new URL(request.url());
  } catch (_) {
    return false;
  }
  if (requestUrl.origin !== qaUrl.origin || !requestUrl.pathname.startsWith(criticalAssetRoot)) {
    return false;
  }
  return /\.(?:js|mjs|wasm|pck)$/i.test(requestUrl.pathname);
}

function finiteNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

function assertProbe(snapshot, label, expectedView) {
  if (!snapshot || typeof snapshot !== 'object') {
    throw new Error(`${label} QA probe is missing`);
  }
  if (snapshot.schema !== 'infinidive.qa.v1') {
    throw new Error(`${label} QA probe has an unexpected schema: ${JSON.stringify(snapshot.schema)}`);
  }
  if (!Number.isInteger(snapshot.revision) || snapshot.revision < 0) {
    throw new Error(`${label} QA probe has an invalid revision: ${JSON.stringify(snapshot.revision)}`);
  }
  if (snapshot.view !== expectedView) {
    throw new Error(`${label} QA probe expected view=${expectedView}: ${JSON.stringify(snapshot)}`);
  }
}

function assertRunProbe(snapshot, label) {
  assertProbe(snapshot, label, 'run');
  if (snapshot.state !== 'EXTERIOR' || snapshot.controls_active !== true
      || snapshot.run_identity_present !== true || snapshot.state_valid !== true
      || snapshot.numeric_state_valid !== true || typeof snapshot.movement_observed !== 'boolean') {
    throw new Error(`${label} QA probe is not an active exterior run: ${JSON.stringify(snapshot)}`);
  }
  if (!Array.isArray(snapshot.player_position) || snapshot.player_position.length !== 2
      || !snapshot.player_position.every(finiteNumber)) {
    throw new Error(`${label} QA probe has an invalid player_position: ${JSON.stringify(snapshot.player_position)}`);
  }
  for (const field of ['dash_time', 'dash_recharge', 'dash_cooldown', 'dash_ratio', 'elapsed']) {
    if (!finiteNumber(snapshot[field])) {
      throw new Error(`${label} QA probe has an invalid ${field}: ${JSON.stringify(snapshot[field])}`);
    }
  }
  for (const field of ['dash_count', 'dash_charges', 'dash_max_charges']) {
    if (!Number.isInteger(snapshot[field]) || snapshot[field] < 0) {
      throw new Error(`${label} QA probe has an invalid ${field}: ${JSON.stringify(snapshot[field])}`);
    }
  }
  if (!Number.isInteger(snapshot.run_generation) || snapshot.run_generation < 1) {
    throw new Error(`${label} QA probe has an invalid run_generation: ${JSON.stringify(snapshot.run_generation)}`);
  }
  if (snapshot.dash_max_charges < 1 || snapshot.dash_charges > snapshot.dash_max_charges
      || snapshot.dash_ratio < 0 || snapshot.dash_ratio > 1) {
    throw new Error(`${label} QA probe has inconsistent Dash state: ${JSON.stringify(snapshot)}`);
  }
}

function assertSameRun(before, after, label) {
  assertRunProbe(after, label);
  if (after.schema !== before.schema || after.revision <= before.revision
      || after.elapsed < before.elapsed || after.run_generation !== before.run_generation) {
    throw new Error(`${label} did not remain in the same monotonic run: ${JSON.stringify({ before, after })}`);
  }
}

function assertRunGeneration(reference, candidate, label) {
  if (candidate.run_generation !== reference.run_generation) {
    throw new Error(`${label} changed run_generation: ${JSON.stringify({ reference, candidate })}`);
  }
}

function playerDisplacement(before, after) {
  return Math.hypot(
    after.player_position[0] - before.player_position[0],
    after.player_position[1] - before.player_position[1],
  );
}

async function qaSnapshot() {
  return page.evaluate(() => {
    const state = globalThis.__INFINIDIVE_QA_STATE;
    return state && typeof state === 'object' ? JSON.parse(JSON.stringify(state)) : null;
  });
}

async function persistEvidence(result, screenshotAlreadyCaptured = false) {
  if (page) {
    try {
      fs.writeFileSync(path.join(evidenceDir, 'infinidive-dom.html'), await page.content());
      if (!screenshotAlreadyCaptured) {
        const failureStage = String(result.semantic_touch?.failure_stage ?? 'unknown')
          .replace(/[^a-z0-9_-]+/gi, '-');
        const failureScreenshotPath = path.join(
          evidenceDir,
          `infinidive-failure-${failureStage}.png`,
        );
        await page.screenshot({
          path: failureScreenshotPath,
          fullPage: true,
        });
        result.failure_screenshot = path.basename(failureScreenshotPath);
        const canonicalScreenshotPath = path.join(evidenceDir, 'infinidive-browser.png');
        if (!fs.existsSync(canonicalScreenshotPath)) {
          fs.copyFileSync(failureScreenshotPath, canonicalScreenshotPath);
        }
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
    qa_url: qaUrl.toString(),
    status: 'failed',
    console_messages: consoleMessages,
    page_errors: pageErrors,
    page_crashes: pageCrashes,
    network: {
      request_failures: requestFailures,
      critical_subresource_non_2xx: criticalSubresourceNon2xx,
      critical_subresource_errors: criticalSubresourceErrors,
    },
    semantic_touch: {
      status: 'in_progress',
      stage: 'launch',
      minimum_player_displacement_px: 12,
      snapshots: {},
    },
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
    page.on('crash', () => pageCrashes.push({ stage: result.semantic_touch.stage }));
    page.on('requestfailed', (request) => {
      const critical = isCriticalGameSubresource(request);
      requestFailures.push({
        url: request.url(),
        method: request.method(),
        resource_type: request.resourceType(),
        error_text: request.failure()?.errorText ?? 'unknown request failure',
        critical,
      });
    });
    page.on('response', (subresourceResponse) => {
      const request = subresourceResponse.request();
      const status = subresourceResponse.status();
      if ((status < 200 || status >= 300) && isCriticalGameSubresource(request)) {
        const evidence = {
          url: subresourceResponse.url(),
          status,
          status_text: subresourceResponse.statusText(),
          resource_type: request.resourceType(),
        };
        criticalSubresourceNon2xx.push(evidence);
        if (status < 200 || status >= 400) criticalSubresourceErrors.push(evidence);
      }
    });

    const response = await page.goto(qaUrl.toString(), {
      waitUntil: 'domcontentloaded',
      timeout: 30_000,
    });
    if (!response || !response.ok()) {
      throw new Error(`Web entry returned HTTP ${response ? response.status() : 'no response'}`);
    }
    result.http_status = response.status();

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
    result.runtime = runtime;

    result.semantic_touch.stage = 'nest_probe';
    await page.waitForFunction(
      () => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === 'infinidive.qa.v1'
          && Number.isInteger(state.revision)
          && state.view === 'nest';
      },
      null,
      { timeout: 15_000 },
    );
    const nestProbe = await qaSnapshot();
    assertProbe(nestProbe, 'Nest', 'nest');
    if (nestProbe.run_generation !== 0) {
      throw new Error(`Nest QA probe did not start with a fresh run generation: ${JSON.stringify(nestProbe)}`);
    }
    result.semantic_touch.snapshots.nest = nestProbe;

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
      globalThis.__infinidiveQaTrace = [];
      globalThis.__infinidiveQaTraceRevision = null;
      globalThis.__infinidiveQaTraceTimer = window.setInterval(() => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        if (!state || state.revision === globalThis.__infinidiveQaTraceRevision) return;
        globalThis.__infinidiveQaTraceRevision = state.revision;
        globalThis.__infinidiveQaTrace.push(JSON.parse(JSON.stringify(state)));
      }, 20);
    });

    const beforeInputPath = path.join(evidenceDir, 'infinidive-before-input.png');
    const beforeInput = await page.screenshot({ path: beforeInputPath, fullPage: true });
    result.semantic_touch.stage_screenshots = {
      nest: path.basename(beforeInputPath),
      latest: 'infinidive-browser.png',
    };
    result.semantic_touch.stage = 'start_tap';
    await page.touchscreen.tap(270, 842);
    await page.waitForTimeout(1_500);

    result.semantic_touch.stage = 'run_start';
    await page.waitForFunction(
      ({ schema, nestRevision, nestRunGeneration }) => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === schema
          && Number.isInteger(state.revision)
          && state.revision > nestRevision
          && state.view === 'run'
          && state.state === 'EXTERIOR'
          && state.controls_active === true
          && state.run_identity_present === true
          && state.state_valid === true
          && state.numeric_state_valid === true
          && state.movement_observed === false
          && Number.isInteger(state.run_generation)
          && state.run_generation === nestRunGeneration + 1
          && Array.isArray(state.player_position)
          && state.player_position.length === 2
          && state.player_position.every(Number.isFinite);
      },
      {
        schema: nestProbe.schema,
        nestRevision: nestProbe.revision,
        nestRunGeneration: nestProbe.run_generation,
      },
      { timeout: 15_000 },
    );
    const runStartProbe = await qaSnapshot();
    assertRunProbe(runStartProbe, 'Run start');
    if (runStartProbe.schema !== nestProbe.schema || runStartProbe.revision <= nestProbe.revision) {
      throw new Error(`Run start did not continue the Nest probe revision: ${JSON.stringify({ nestProbe, runStartProbe })}`);
    }
    if (runStartProbe.run_generation !== nestProbe.run_generation + 1) {
      throw new Error(`Run start did not create exactly one run generation: ${JSON.stringify({ nestProbe, runStartProbe })}`);
    }
    result.semantic_touch.snapshots.run_start = runStartProbe;

    const cdp = await context.newCDPSession(page);
    result.semantic_touch.stage = 'movement_drag';
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

    result.semantic_touch.stage = 'movement_assertion';
    await page.waitForFunction(
      ({ schema, revision, elapsed, runGeneration, dashCount, position, minimumDistance }) => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        if (state?.schema !== schema || state.view !== 'run' || state.state !== 'EXTERIOR'
            || state.controls_active !== true || state.run_identity_present !== true
            || state.state_valid !== true || state.numeric_state_valid !== true
            || state.movement_observed !== true
            || state.run_generation !== runGeneration
            || state.dash_count !== dashCount
            || !Number.isInteger(state.revision) || state.revision <= revision
            || !Number.isFinite(state.elapsed) || state.elapsed < elapsed
            || !Array.isArray(state.player_position) || state.player_position.length !== 2
            || !state.player_position.every(Number.isFinite)) return false;
        return Math.hypot(
          state.player_position[0] - position[0],
          state.player_position[1] - position[1],
        ) >= minimumDistance;
      },
      {
        schema: runStartProbe.schema,
        revision: runStartProbe.revision,
        elapsed: runStartProbe.elapsed,
        runGeneration: runStartProbe.run_generation,
        dashCount: runStartProbe.dash_count,
        position: runStartProbe.player_position,
        minimumDistance: result.semantic_touch.minimum_player_displacement_px,
      },
      { timeout: 5_000 },
    );
    const afterMoveProbe = await qaSnapshot();
    assertSameRun(runStartProbe, afterMoveProbe, 'Movement');
    if (runStartProbe.movement_observed !== false || afterMoveProbe.movement_observed !== true
        || afterMoveProbe.dash_count !== runStartProbe.dash_count) {
      throw new Error(`Movement semantics changed an unexpected state: ${JSON.stringify({ runStartProbe, afterMoveProbe })}`);
    }
    const displacementPx = playerDisplacement(runStartProbe, afterMoveProbe);
    if (displacementPx < result.semantic_touch.minimum_player_displacement_px) {
      throw new Error(`Player displacement was only ${displacementPx}px`);
    }
    result.semantic_touch.snapshots.after_move = afterMoveProbe;
    result.semantic_touch.player_displacement_px = displacementPx;

    result.semantic_touch.stage = 'dash_ready';
    await page.waitForFunction(
      ({ schema, runGeneration, dashCount, minimumRevision, minimumElapsed }) => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === schema
          && state.view === 'run'
          && state.state === 'EXTERIOR'
          && state.controls_active === true
          && state.run_identity_present === true
          && state.state_valid === true
          && state.numeric_state_valid === true
          && state.run_generation === runGeneration
          && state.dash_count === dashCount
          && Number.isInteger(state.revision)
          && state.revision >= minimumRevision
          && Number.isFinite(state.elapsed)
          && state.elapsed >= minimumElapsed
          && Number.isInteger(state.dash_charges)
          && state.dash_charges >= 1;
      },
      {
        schema: afterMoveProbe.schema,
        runGeneration: afterMoveProbe.run_generation,
        dashCount: afterMoveProbe.dash_count,
        minimumRevision: afterMoveProbe.revision,
        minimumElapsed: afterMoveProbe.elapsed,
      },
      { timeout: 15_000 },
    );
    const beforeDashProbe = await qaSnapshot();
    assertRunProbe(beforeDashProbe, 'Before Dash');
    assertRunGeneration(afterMoveProbe, beforeDashProbe, 'Dash readiness');
    if (beforeDashProbe.elapsed < afterMoveProbe.elapsed) {
      throw new Error(`Dash readiness restarted elapsed time: ${JSON.stringify({ afterMoveProbe, beforeDashProbe })}`);
    }
    if (beforeDashProbe.dash_charges < 1) {
      throw new Error(`Dash was not charged before the Dash tap: ${JSON.stringify(beforeDashProbe)}`);
    }
    if (beforeDashProbe.dash_count !== runStartProbe.dash_count) {
      throw new Error(`Dash count changed before the Dash tap: ${JSON.stringify({ runStartProbe, beforeDashProbe })}`);
    }
    result.semantic_touch.snapshots.before_dash = beforeDashProbe;

    result.semantic_touch.stage = 'dash_tap';
    await page.touchscreen.tap(72, 874);
    await page.waitForFunction(
      ({ schema, revision, elapsed, runGeneration, dashCount, dashCharges }) => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === schema
          && state.view === 'run'
          && state.state === 'EXTERIOR'
          && state.controls_active === true
          && state.run_identity_present === true
          && state.state_valid === true
          && state.numeric_state_valid === true
          && state.run_generation === runGeneration
          && Number.isInteger(state.revision)
          && state.revision > revision
          && Number.isFinite(state.elapsed)
          && state.elapsed >= elapsed
          && state.dash_count === dashCount + 1
          && Number.isInteger(state.dash_charges)
          && state.dash_charges < dashCharges;
      },
      {
        schema: beforeDashProbe.schema,
        revision: beforeDashProbe.revision,
        elapsed: beforeDashProbe.elapsed,
        runGeneration: beforeDashProbe.run_generation,
        dashCount: beforeDashProbe.dash_count,
        dashCharges: beforeDashProbe.dash_charges,
      },
      { timeout: 5_000 },
    );
    const dashAcceptedProbe = await qaSnapshot();
    assertSameRun(beforeDashProbe, dashAcceptedProbe, 'Dash acceptance');
    if (dashAcceptedProbe.dash_count !== beforeDashProbe.dash_count + 1
        || dashAcceptedProbe.dash_charges >= beforeDashProbe.dash_charges) {
      throw new Error(`Dash count/charge evidence is invalid: ${JSON.stringify({ beforeDashProbe, dashAcceptedProbe })}`);
    }
    result.semantic_touch.snapshots.dash_accepted = dashAcceptedProbe;

    result.semantic_touch.stage = 'dash_durability';
    await page.waitForTimeout(1_500);
    const dashDurableProbe = await qaSnapshot();
    assertSameRun(dashAcceptedProbe, dashDurableProbe, 'Durable Dash');
    if (dashDurableProbe.dash_count !== dashAcceptedProbe.dash_count) {
      throw new Error(`Dash count was not durable: ${JSON.stringify({ dashAcceptedProbe, dashDurableProbe })}`);
    }
    result.semantic_touch.snapshots.dash_durable = dashDurableProbe;

    result.semantic_touch.stage = 'post_input_runtime';
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
    result.semantic_touch.stage = 'render_evidence';
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
    result.semantic_touch.stage = 'same_run_trace';
    const qaTrace = await page.evaluate(() => {
      window.clearInterval(globalThis.__infinidiveQaTraceTimer);
      return JSON.parse(JSON.stringify(globalThis.__infinidiveQaTrace ?? []));
    });
    const sameRunTrace = qaTrace.filter((snapshot) => snapshot.revision >= runStartProbe.revision);
    let previousTraceRevision = runStartProbe.revision - 1;
    let previousTraceElapsed = runStartProbe.elapsed;
    for (const snapshot of sameRunTrace) {
      if (snapshot.schema !== runStartProbe.schema || snapshot.view !== 'run'
          || snapshot.run_identity_present !== true || snapshot.state_valid !== true
          || snapshot.numeric_state_valid !== true || !Number.isFinite(snapshot.elapsed)
          || snapshot.run_generation !== runStartProbe.run_generation
          || !Number.isInteger(snapshot.revision) || snapshot.revision <= previousTraceRevision
          || snapshot.elapsed < previousTraceElapsed) {
        throw new Error(`QA revision trace left or restarted the active run: ${JSON.stringify(snapshot)}`);
      }
      previousTraceRevision = snapshot.revision;
      previousTraceElapsed = snapshot.elapsed;
    }
    if (!sameRunTrace.length) {
      throw new Error('QA revision trace did not retain the active run');
    }
    result.semantic_touch.stage = 'runtime_error_gate';
    const criticalRequestFailures = requestFailures.filter((failure) => failure.critical);
    result.network.request_failure_count = requestFailures.length;
    result.network.critical_request_failure_count = criticalRequestFailures.length;
    result.network.ignored_request_failure_count = requestFailures.length - criticalRequestFailures.length;
    result.network.critical_non_2xx_count = criticalSubresourceNon2xx.length;
    result.network.critical_subresource_error_count = criticalSubresourceErrors.length;
    if (criticalRequestFailures.length || criticalSubresourceErrors.length) {
      throw new Error('A critical game subresource failed to load');
    }
    if (pageCrashes.length) {
      throw new Error('The game page crashed during the semantic touch smoke');
    }
    if (pageErrors.length || consoleMessages.some((message) => message.type === 'error')) {
      throw new Error('The running page emitted a JavaScript or console error');
    }

    result.status = 'passed';
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
    result.semantic_touch.status = 'passed';
    result.semantic_touch.stage = 'complete';
    result.semantic_touch.qa_revision_trace = sameRunTrace;
    result.semantic_touch.same_run = {
      method: 'stable schema/view/identity/run_generation with monotonic revision and elapsed trace',
      run_generation: runStartProbe.run_generation,
      first_revision: runStartProbe.revision,
      last_revision: dashDurableProbe.revision,
      first_elapsed: runStartProbe.elapsed,
      last_elapsed: dashDurableProbe.elapsed,
      traced_revisions: sameRunTrace.map((snapshot) => ({
        revision: snapshot.revision,
        view: snapshot.view,
        state: snapshot.state,
        elapsed: snapshot.elapsed,
        run_identity_present: snapshot.run_identity_present,
        run_generation: snapshot.run_generation,
      })),
    };
    result.semantic_touch.assertions = {
      nest_probe: true,
      run_started_in_exterior: true,
      controls_active: true,
      run_identity_present: true,
      player_moved_at_least_12_px: true,
      dash_was_charged_before_tap: true,
      dash_count_incremented: true,
      dash_charge_decreased: true,
      dash_count_remained_incremented: true,
      run_generation_stable: true,
      numeric_state_valid: true,
      state_valid: true,
      movement_observed_only_after_drag: true,
    };
    await persistEvidence(result, true);
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } catch (error) {
    result.semantic_touch.status = 'failed';
    result.semantic_touch.failure_stage = result.semantic_touch.stage;
    if (page && !page.isClosed()) {
      try {
        result.semantic_touch.latest_probe = await qaSnapshot();
        result.semantic_touch.partial_revision_trace = await page.evaluate(() => {
          window.clearInterval(globalThis.__infinidiveQaTraceTimer);
          return JSON.parse(JSON.stringify(globalThis.__infinidiveQaTrace ?? []));
        });
      } catch (probeError) {
        result.semantic_touch.probe_evidence_error = String(probeError);
      }
    }
    const criticalRequestFailures = requestFailures.filter((failure) => failure.critical);
    result.network.request_failure_count = requestFailures.length;
    result.network.critical_request_failure_count = criticalRequestFailures.length;
    result.network.ignored_request_failure_count = requestFailures.length - criticalRequestFailures.length;
    result.network.critical_non_2xx_count = criticalSubresourceNon2xx.length;
    result.network.critical_subresource_error_count = criticalSubresourceErrors.length;
    result.failure = String(error);
    await persistEvidence(result);
    process.stderr.write(`${JSON.stringify(result, null, 2)}\n`);
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close();
  }
})();
