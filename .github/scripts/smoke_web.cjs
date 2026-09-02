'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const targetUrl = process.argv[2];
const evidenceDir = process.argv[3];
const chromeBin = process.env.INFINIDIVE_CHROME_BIN;
const playwrightRoot = process.env.INFINIDIVE_PLAYWRIGHT_ROOT;
const storeCaptureEnabled = process.env.INFINIDIVE_STORE_CAPTURE === '1';
const sourceCommit = process.env.INFINIDIVE_SOURCE_COMMIT ?? process.env.GITHUB_SHA ?? '';
const sourceRepository = process.env.INFINIDIVE_SOURCE_REPOSITORY ?? process.env.GITHUB_REPOSITORY ?? '';
const sourceRunId = process.env.INFINIDIVE_SOURCE_RUN_ID ?? process.env.GITHUB_RUN_ID ?? '';
const sourceRunAttempt = process.env.INFINIDIVE_SOURCE_RUN_ATTEMPT ?? process.env.GITHUB_RUN_ATTEMPT ?? '';

if (!targetUrl || !evidenceDir || !chromeBin || !playwrightRoot) {
  throw new Error('Web smoke requires URL, evidence directory, Chrome, and Playwright root');
}

const { chromium } = require(path.join(playwrightRoot, 'node_modules', 'playwright-core'));
fs.mkdirSync(evidenceDir, { recursive: true });

const BASE_VIEWPORT = Object.freeze({ width: 540, height: 960 });
const STORE_VIEWPORT = Object.freeze({ width: 1320, height: 2868 });
const STORE_CAPTURE_MANIFEST = 'infinidive-store-capture.json';
const STORE_CAPTURE_CLASSIFICATION = 'current_source_ci_browser_app_store_sized_review_candidate_not_target_device_submission_evidence';
const STORE_CONTRACT_PATH = path.resolve(
  __dirname,
  '..',
  '..',
  'infinidive-game',
  'assets',
  'store',
  'gameplay',
  'capture-manifest.json',
);

function loadStoreCaptureContract() {
  if (!storeCaptureEnabled) return null;
  const document = JSON.parse(fs.readFileSync(STORE_CONTRACT_PATH, 'utf8'));
  const contract = document?.planned_capture?.ci_store_sized_screenshots;
  if (!contract || contract.schema_version !== 1
      || contract.classification !== STORE_CAPTURE_CLASSIFICATION
      || contract.evidence_manifest !== STORE_CAPTURE_MANIFEST
      || contract.expected_image?.width !== STORE_VIEWPORT.width
      || contract.expected_image?.height !== STORE_VIEWPORT.height
      || contract.expected_image?.device_scale_factor !== 1
      || contract.expected_image?.post_capture_scaling !== false
      || !Array.isArray(contract.ordered_stages)
      || contract.ordered_stages.length < 1) {
    throw new Error('The static store-capture contract is missing or unsafe');
  }
  const orders = new Set();
  const keys = new Set();
  const sourceStages = new Set();
  const files = new Set();
  for (const stage of contract.ordered_stages) {
    if (!Number.isInteger(stage.order) || stage.order < 1 || orders.has(stage.order)
        || typeof stage.key !== 'string' || !/^[a-z0-9-]+$/.test(stage.key) || keys.has(stage.key)
        || typeof stage.source_stage !== 'string' || !/^[a-z0-9_-]+$/.test(stage.source_stage)
        || sourceStages.has(stage.source_stage)
        || typeof stage.snapshot_key !== 'string' || !/^[a-z0-9_]+$/.test(stage.snapshot_key)
        || typeof stage.file !== 'string' || stage.file !== path.basename(stage.file)
        || !stage.file.endsWith('.png') || files.has(stage.file)
        || typeof stage.caption !== 'string' || stage.caption.length < 1
        || !stage.required_qa || typeof stage.required_qa !== 'object'
        || Array.isArray(stage.required_qa)) {
      throw new Error(`Unsafe store-capture stage contract: ${JSON.stringify(stage)}`);
    }
    orders.add(stage.order);
    keys.add(stage.key);
    sourceStages.add(stage.source_stage);
    files.add(stage.file);
  }
  const sortedOrders = [...orders].sort((left, right) => left - right);
  if (sortedOrders.some((order, index) => order !== index + 1)) {
    throw new Error(`Store-capture stage order is not contiguous: ${JSON.stringify(sortedOrders)}`);
  }
  if (!/^[0-9a-f]{40,64}$/.test(sourceCommit)
      || !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(sourceRepository)
      || !/^\d+$/.test(sourceRunId) || Number(sourceRunId) < 1
      || !/^\d+$/.test(sourceRunAttempt) || Number(sourceRunAttempt) < 1) {
    throw new Error('Store capture requires a valid commit, repository, run ID, and run attempt source binding');
  }
  return contract;
}

const storeCaptureContract = loadStoreCaptureContract();

const QA_SCHEMA = 'infinidive.qa.v2';
const EXPECTED_CORE_PATH = [
  'EXTERIOR',
  'BREACH_OPEN',
  'ORGAN_SELECT',
  'DIVING_IN',
  'INTERNAL_ROOMS',
  'ORGAN_CHAMBER',
  'MUTATION_CHOICE',
  'DIVING_OUT',
  'EXTERIOR',
];
const TERMINAL_RUN_STATES = new Set(['DEAD', 'VICTORY']);
const ACTIVE_INPUT_STATES = new Set(['EXTERIOR', 'BREACH_OPEN', 'INTERNAL_ROOMS', 'ORGAN_CHAMBER', 'CORE']);
const TARGET_HEALTH_STATES = new Set(['EXTERIOR', 'ORGAN_CHAMBER', 'CORE']);
const QA_ORGAN_IDS = new Set([
  'bone_forge', 'brood_sac', 'echo_heart', 'gravity_lung', 'halo_choir', 'hunter_eye',
  'memory_cortex', 'prism_cortex', 'reflection_lattice', 'shock_gland', 'vortex_stomach',
  'wing_reactor',
]);
const QA_ABILITY_IDS = new Set([
  'bone_missiles', 'chain_lightning', 'echo_dash', 'false_weakpoints', 'gravity_ring',
  'halo_barrier', 'homing_eye', 'laser_wings', 'parasite_swarm', 'prism_lances',
  'suction_waves', 'weapon_copy',
]);
const QA_BOSS_VISUAL_STATES = new Set([
  'blinded_hunter_eye', 'collapsed_gravity_lung', 'collapsed_laser_wing',
  'cracked_prism_cortex', 'erased_memory_cortex', 'fractured_halo_choir',
  'grounded_shock_gland', 'ruptured_vortex_stomach', 'sealed_bone_forge',
  'sealed_brood_sac', 'shattered_reflection_lattice', 'stilled_echo_heart',
]);
const QA_MUTATION_IDS = new Set([
  'breach_hunger', 'calm_between_beats', 'cellular_magnet', 'core_resonance',
  'deep_adaptation', 'echo_shot', 'emergency_sheath', 'ghost_charge', 'glass_engine',
  'hungry_orbit', 'infinite_recoil', 'last_pulse', 'needle_through_bone',
  'overclocked_iris', 'parasite_leech', 'phase_capacitor', 'phase_wake',
  'predator_vector', 'rupture_tax', 'second_skin', 'serrated_signal', 'split_chamber',
  'symbiotic_guard', 'wound_memory',
]);
const MAX_PHASE = 3;
const MAX_TUTORIAL_STEPS = 10;
const MAX_DIAGNOSTIC_ENTRIES = 128;
const MAX_DIAGNOSTIC_TEXT_LENGTH = 1_024;
const COMMON_QA_KEYS = [
  'ability',
  'boss_visual_state',
  'health',
  'mutation',
  'organ',
  'persistence',
  'phase',
  'revision',
  'run_generation',
  'schema',
  'view',
];
const RUN_QA_KEYS = [
  ...COMMON_QA_KEYS,
  'controls_active',
  'dash_charges',
  'dash_cooldown',
  'dash_count',
  'dash_max_charges',
  'dash_ratio',
  'dash_recharge',
  'dash_time',
  'elapsed',
  'movement_observed',
  'numeric_state_valid',
  'player_position',
  'run_identity_present',
  'state',
  'state_valid',
];

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
let consoleMessageCount = 0;
let pageErrorCount = 0;
let pageCrashCount = 0;
let requestFailureCount = 0;
let criticalRequestFailureCount = 0;
let criticalNon2xxCount = 0;
let criticalSubresourceErrorCount = 0;
let sawConsoleError = false;
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

function nullableFiniteRatio(value) {
  return value === null || (finiteNumber(value) && value >= 0 && value <= 1);
}

function nullableBoundedInteger(value, maximum) {
  return value === null || (Number.isInteger(value) && value >= 0 && value <= maximum);
}

function nullableCatalogId(value, catalog) {
  return value === null || (typeof value === 'string' && catalog.has(value));
}

function boundedDiagnosticText(value) {
  return String(value).slice(0, MAX_DIAGNOSTIC_TEXT_LENGTH);
}

function appendBoundedDiagnostic(target, value) {
  if (target.length < MAX_DIAGNOSTIC_ENTRIES) target.push(value);
}

function sanitizedEvidenceUrl(rawUrl, retainQaFlag = false) {
  try {
    const parsed = new URL(rawUrl);
    parsed.username = '';
    parsed.password = '';
    parsed.hash = '';
    const qaEnabled = retainQaFlag && parsed.searchParams.get('infinidive_qa') === '1';
    parsed.search = qaEnabled ? '?infinidive_qa=1' : '';
    return parsed.toString();
  } catch (_) {
    return '<invalid-url>';
  }
}

function assertExactKeys(value, expectedKeys, label) {
  const actualKeys = Object.keys(value).sort();
  const sortedExpected = [...expectedKeys].sort();
  if (actualKeys.length !== sortedExpected.length
      || actualKeys.some((key, index) => key !== sortedExpected[index])) {
    throw new Error(`${label} has unexpected keys: ${JSON.stringify({ expected: sortedExpected, actual: actualKeys })}`);
  }
}

function assertV2Contract(snapshot, label, expectedView) {
  assertExactKeys(snapshot, expectedView === 'run' ? RUN_QA_KEYS : COMMON_QA_KEYS, `${label} QA probe`);
  if (snapshot.schema !== QA_SCHEMA) {
    throw new Error(`${label} QA probe has an unexpected schema: ${JSON.stringify(snapshot.schema)}`);
  }
  if (!nullableBoundedInteger(snapshot.phase, MAX_PHASE)) {
    throw new Error(`${label} QA probe has an invalid phase: ${JSON.stringify(snapshot.phase)}`);
  }
  if (!snapshot.health || typeof snapshot.health !== 'object'
      || !nullableFiniteRatio(snapshot.health.player_ratio)
      || !nullableFiniteRatio(snapshot.health.target_ratio)) {
    throw new Error(`${label} QA probe has an invalid health contract: ${JSON.stringify(snapshot.health)}`);
  }
  assertExactKeys(snapshot.health, ['player_ratio', 'target_ratio'], `${label} health contract`);
  if (!snapshot.organ || typeof snapshot.organ !== 'object'
      || !nullableCatalogId(snapshot.organ.id, QA_ORGAN_IDS)
      || ![null, 'selected', 'destroyed'].includes(snapshot.organ.status)
      || !nullableFiniteRatio(snapshot.organ.health_ratio)) {
    throw new Error(`${label} QA probe has an invalid organ contract: ${JSON.stringify(snapshot.organ)}`);
  }
  assertExactKeys(snapshot.organ, ['health_ratio', 'id', 'status'], `${label} organ contract`);
  if (!snapshot.ability || typeof snapshot.ability !== 'object'
      || !nullableCatalogId(snapshot.ability.id, QA_ABILITY_IDS)
      || ![null, 'active', 'degraded', 'disabled'].includes(snapshot.ability.status)) {
    throw new Error(`${label} QA probe has an invalid ability contract: ${JSON.stringify(snapshot.ability)}`);
  }
  assertExactKeys(snapshot.ability, ['id', 'status'], `${label} ability contract`);
  if (!nullableCatalogId(snapshot.boss_visual_state, QA_BOSS_VISUAL_STATES)) {
    throw new Error(`${label} QA probe has an invalid boss_visual_state: ${JSON.stringify(snapshot.boss_visual_state)}`);
  }
  if (!snapshot.mutation || typeof snapshot.mutation !== 'object'
      || !nullableBoundedInteger(snapshot.mutation.offered_count, 3)
      || !nullableBoundedInteger(snapshot.mutation.selected_count, QA_MUTATION_IDS.size)
      || !nullableCatalogId(snapshot.mutation.last_selected_id, QA_MUTATION_IDS)) {
    throw new Error(`${label} QA probe has an invalid mutation contract: ${JSON.stringify(snapshot.mutation)}`);
  }
  assertExactKeys(snapshot.mutation, ['last_selected_id', 'offered_count', 'selected_count'], `${label} mutation contract`);
  if (!snapshot.persistence || typeof snapshot.persistence !== 'object'
      || !nullableBoundedInteger(snapshot.persistence.tutorial_step_count, MAX_TUTORIAL_STEPS)
      || !nullableBoundedInteger(snapshot.persistence.mutation_discovery_count, QA_MUTATION_IDS.size)
      || ![null, 'default', 'primary', 'backup'].includes(snapshot.persistence.save_source)) {
    throw new Error(`${label} QA probe has an invalid persistence contract: ${JSON.stringify(snapshot.persistence)}`);
  }
  assertExactKeys(
    snapshot.persistence,
    ['mutation_discovery_count', 'save_source', 'tutorial_step_count'],
    `${label} persistence contract`,
  );
  if ((snapshot.organ.id === null) !== (snapshot.organ.status === null)
      || (snapshot.organ.id === null && snapshot.organ.health_ratio !== null)
      || (snapshot.ability.id === null) !== (snapshot.ability.status === null)
      || (snapshot.boss_visual_state !== null && snapshot.organ.status !== 'destroyed')
      || (snapshot.mutation.selected_count === null && snapshot.mutation.last_selected_id !== null)
      || (snapshot.mutation.selected_count === 0 && snapshot.mutation.last_selected_id !== null)
      || (snapshot.mutation.selected_count !== null && snapshot.mutation.selected_count > 0
        && snapshot.mutation.last_selected_id === null)) {
    throw new Error(`${label} QA probe has inconsistent nullable relationships: ${JSON.stringify(snapshot)}`);
  }
  if (expectedView === 'run') {
    if (!Number.isInteger(snapshot.phase) || snapshot.phase < 0
        || snapshot.health.player_ratio === null
        || snapshot.mutation.offered_count === null || snapshot.mutation.selected_count === null
        || snapshot.persistence.tutorial_step_count === null
        || snapshot.persistence.mutation_discovery_count === null
        || snapshot.persistence.save_source === null) {
      throw new Error(`${label} QA probe has null active-run fields: ${JSON.stringify(snapshot)}`);
    }
    if (TARGET_HEALTH_STATES.has(snapshot.state) && snapshot.health.target_ratio === null) {
      throw new Error(`${label} QA probe has no target health in ${snapshot.state}: ${JSON.stringify(snapshot.health)}`);
    }
  }
}

function assertProbe(snapshot, label, expectedView) {
  if (!snapshot || typeof snapshot !== 'object') {
    throw new Error(`${label} QA probe is missing`);
  }
  assertV2Contract(snapshot, label, expectedView);
  if (!Number.isInteger(snapshot.revision) || snapshot.revision < 0) {
    throw new Error(`${label} QA probe has an invalid revision: ${JSON.stringify(snapshot.revision)}`);
  }
  if (snapshot.view !== expectedView) {
    throw new Error(`${label} QA probe expected view=${expectedView}: ${JSON.stringify(snapshot)}`);
  }
}

function assertNestEnvelopeIsReadOnly(snapshot, label) {
  if (snapshot.phase !== null
      || snapshot.health.player_ratio !== null
      || snapshot.health.target_ratio !== null
      || snapshot.organ.id !== null
      || snapshot.organ.status !== null
      || snapshot.organ.health_ratio !== null
      || snapshot.ability.id !== null
      || snapshot.ability.status !== null
      || snapshot.boss_visual_state !== null
      || snapshot.mutation.offered_count !== null
      || snapshot.mutation.selected_count !== null
      || snapshot.mutation.last_selected_id !== null) {
    throw new Error(`${label} Nest probe leaked run state: ${JSON.stringify(snapshot)}`);
  }
}

function assertRunProbe(snapshot, label, expectedState = 'EXTERIOR', expectedControls = null) {
  assertProbe(snapshot, label, 'run');
  if (snapshot.state !== expectedState
      || snapshot.run_identity_present !== true || snapshot.state_valid !== true
      || snapshot.numeric_state_valid !== true || typeof snapshot.movement_observed !== 'boolean'
      || typeof snapshot.controls_active !== 'boolean') {
    throw new Error(`${label} QA probe is not an active ${expectedState} run: ${JSON.stringify(snapshot)}`);
  }
  if (expectedControls !== null && snapshot.controls_active !== expectedControls) {
    throw new Error(`${label} QA probe expected controls_active=${expectedControls}: ${JSON.stringify(snapshot)}`);
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
  assertRunProbe(after, label, before.state, before.controls_active);
  if (after.schema !== before.schema || after.revision <= before.revision
      || after.elapsed < before.elapsed || after.run_generation !== before.run_generation) {
    throw new Error(`${label} did not remain in the same monotonic run: ${JSON.stringify({ before, after })}`);
  }
}

function assertRunTransition(before, after, label, expectedState, expectedControls = null) {
  assertRunProbe(after, label, expectedState, expectedControls);
  if (after.schema !== before.schema || after.revision <= before.revision
      || after.elapsed < before.elapsed || after.run_generation !== before.run_generation) {
    throw new Error(`${label} did not advance the same monotonic run: ${JSON.stringify({ before, after })}`);
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

async function dispatchDrag(cdp, from, to, touchId) {
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchStart',
    touchPoints: [{ x: from[0], y: from[1], id: touchId, radiusX: 2, radiusY: 2, force: 1 }],
  });
  const steps = 3;
  for (let index = 1; index <= steps; index += 1) {
    const ratio = index / steps;
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: [{
        x: from[0] + (to[0] - from[0]) * ratio,
        y: from[1] + (to[1] - from[1]) * ratio,
        id: touchId,
        radiusX: 2,
        radiusY: 2,
        force: 1,
      }],
    });
    await page.waitForTimeout(55);
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

async function driveUntilState(cdp, expectedState, timeoutMs, label) {
  const startedAt = Date.now();
  const patrol = [
    [[270, 790], [120, 760]],
    [[120, 760], [420, 690]],
    [[420, 690], [270, 620]],
    [[270, 620], [420, 780]],
    [[420, 780], [120, 690]],
  ];
  let patrolIndex = 0;
  let touchId = 20;
  while (Date.now() - startedAt < timeoutMs) {
    const snapshot = await qaSnapshot();
    if (!snapshot || snapshot.schema !== QA_SCHEMA || snapshot.view !== 'run') {
      await page.waitForTimeout(100);
      continue;
    }
    if (snapshot.state === expectedState) {
      assertRunProbe(snapshot, label, expectedState, snapshot.controls_active);
      return snapshot;
    }
    if (TERMINAL_RUN_STATES.has(snapshot.state)) {
      throw new Error(`${label} reached terminal state ${snapshot.state} before ${expectedState}: ${JSON.stringify(snapshot)}`);
    }
    if (ACTIVE_INPUT_STATES.has(snapshot.state) && snapshot.controls_active === true) {
      const [from, to] = patrol[patrolIndex % patrol.length];
      patrolIndex += 1;
      touchId += 1;
      await dispatchDrag(cdp, from, to, touchId);
      if (snapshot.dash_charges >= 1
          && (snapshot.health?.player_ratio <= 0.8 || patrolIndex % 4 === 0)) {
        await page.touchscreen.tap(72, 874);
      }
    }
    await page.waitForTimeout(160);
  }
  throw new Error(`${label} timed out after ${timeoutMs}ms waiting for ${expectedState}: ${JSON.stringify(await qaSnapshot())}`);
}

async function waitForRunState(expectedState, runGeneration, afterRevision, timeoutMs, label) {
  await page.waitForFunction(
    ({ schema, stateName, generation, revision }) => {
      const state = globalThis.__INFINIDIVE_QA_STATE;
      return state?.schema === schema
        && state.view === 'run'
        && state.state === stateName
        && state.run_generation === generation
        && Number.isInteger(state.revision)
        && state.revision > revision;
    },
    {
      schema: QA_SCHEMA,
      stateName: expectedState,
      generation: runGeneration,
      revision: afterRevision,
    },
    { timeout: timeoutMs },
  );
  const snapshot = await qaSnapshot();
  assertRunProbe(snapshot, label, expectedState, snapshot.controls_active);
  return snapshot;
}

function valueAtPath(value, dottedPath) {
  return dottedPath.split('.').reduce(
    (cursor, segment) => (cursor && typeof cursor === 'object' ? cursor[segment] : undefined),
    value,
  );
}

function assertStoreStageQa(snapshot, stage) {
  if (!snapshot || typeof snapshot !== 'object') {
    throw new Error(`Store stage ${stage.key} has no QA snapshot`);
  }
  for (const [field, expected] of Object.entries(stage.required_qa)) {
    const actual = valueAtPath(snapshot, field);
    if (actual !== expected) {
      throw new Error(`Store stage ${stage.key} expected QA ${field}=${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
    }
  }
}

function storeQaEvidence(snapshot) {
  return {
    schema: snapshot.schema ?? null,
    view: snapshot.view ?? null,
    state: snapshot.state ?? null,
    revision: snapshot.revision ?? null,
    run_generation: snapshot.run_generation ?? null,
    phase: snapshot.phase ?? null,
    movement_observed: snapshot.movement_observed ?? null,
    organ: snapshot.organ ? JSON.parse(JSON.stringify(snapshot.organ)) : null,
    ability: snapshot.ability ? JSON.parse(JSON.stringify(snapshot.ability)) : null,
    boss_visual_state: snapshot.boss_visual_state ?? null,
    mutation: snapshot.mutation ? JSON.parse(JSON.stringify(snapshot.mutation)) : null,
  };
}

async function waitForCanvasSize(expectedViewport, label) {
  await page.waitForFunction(
    ({ width, height }) => {
      const canvas = document.getElementById('canvas');
      const status = document.getElementById('status');
      return canvas?.width === width
        && canvas?.height === height
        && status?.classList.contains('hidden') === true;
    },
    expectedViewport,
    { timeout: 10_000 },
  );
  const observed = await page.evaluate(() => {
    const canvas = document.getElementById('canvas');
    return { width: canvas?.width ?? 0, height: canvas?.height ?? 0 };
  });
  if (observed.width !== expectedViewport.width || observed.height !== expectedViewport.height) {
    throw new Error(`${label} canvas dimensions are wrong: ${JSON.stringify(observed)}`);
  }
}

async function captureStoreScreenshot(result, sourceStage) {
  if (!storeCaptureContract) return;
  const stage = storeCaptureContract.ordered_stages.find(
    (candidate) => candidate.source_stage === sourceStage,
  );
  if (!stage) {
    throw new Error(`No store-capture contract exists for source stage ${JSON.stringify(sourceStage)}`);
  }
  if (result.store_capture.stages.some((candidate) => candidate.key === stage.key)) {
    throw new Error(`Store stage ${stage.key} was captured more than once`);
  }
  const contractSnapshot = result.semantic_touch.snapshots[stage.snapshot_key];
  assertStoreStageQa(contractSnapshot, stage);
  const originalViewport = page.viewportSize();
  if (!originalViewport
      || originalViewport.width !== BASE_VIEWPORT.width
      || originalViewport.height !== BASE_VIEWPORT.height) {
    throw new Error(`Store capture began outside the base viewport: ${JSON.stringify(originalViewport)}`);
  }
  let screenshot;
  let liveSnapshot;
  try {
    await page.setViewportSize(STORE_VIEWPORT);
    await waitForCanvasSize(STORE_VIEWPORT, `Store stage ${stage.key}`);
    await page.evaluate(() => new Promise((resolve) => {
      requestAnimationFrame(() => requestAnimationFrame(resolve));
    }));
    liveSnapshot = await qaSnapshot();
    assertStoreStageQa(liveSnapshot, stage);
    screenshot = await page.screenshot({
      path: path.join(evidenceDir, stage.file),
      fullPage: false,
      type: 'png',
    });
    const afterScreenshotSnapshot = await qaSnapshot();
    assertStoreStageQa(afterScreenshotSnapshot, stage);
    if (afterScreenshotSnapshot.view !== liveSnapshot.view
        || (liveSnapshot.view === 'run'
          && (afterScreenshotSnapshot.state !== liveSnapshot.state
            || afterScreenshotSnapshot.run_generation !== liveSnapshot.run_generation))) {
      throw new Error(`Store stage ${stage.key} changed gameplay state during capture`);
    }
  } finally {
    await page.setViewportSize(BASE_VIEWPORT);
    await waitForCanvasSize(BASE_VIEWPORT, `Store stage ${stage.key} restore`);
  }
  const digest = crypto.createHash('sha256').update(screenshot).digest('hex');
  result.store_capture.stages.push({
    order: stage.order,
    key: stage.key,
    source_stage: stage.source_stage,
    snapshot_key: stage.snapshot_key,
    file: stage.file,
    caption: stage.caption,
    sha256: digest,
    bytes: screenshot.length,
    width: STORE_VIEWPORT.width,
    height: STORE_VIEWPORT.height,
    device_scale_factor: 1,
    post_capture_scaling: false,
    qa: storeQaEvidence(liveSnapshot),
  });
}

async function captureStageScreenshot(result, stageName) {
  if (!/^[a-z0-9-]+$/.test(stageName)) {
    throw new Error(`Unsafe screenshot stage name: ${JSON.stringify(stageName)}`);
  }
  await page.waitForTimeout(100);
  const fileName = `infinidive-stage-${stageName}.png`;
  const screenshot = await page.screenshot({
    path: path.join(evidenceDir, fileName),
    fullPage: true,
  });
  result.semantic_touch.stage_screenshots[stageName] = fileName;
  result.semantic_touch.stage_screenshot_sha256[stageName] = crypto
    .createHash('sha256')
    .update(screenshot)
    .digest('hex');
  await captureStoreScreenshot(result, stageName);
}

function persistStoreCaptureManifest(result) {
  if (!storeCaptureContract) return;
  const orderedStages = [...result.store_capture.stages]
    .sort((left, right) => left.order - right.order);
  const expectedCount = storeCaptureContract.ordered_stages.length;
  const complete = orderedStages.length === expectedCount
    && orderedStages.every((stage, index) => stage.order === index + 1);
  const passed = result.status === 'passed'
    && result.semantic_touch.status === 'passed'
    && complete;
  result.store_capture.status = passed ? 'passed' : 'failed';
  result.store_capture.captured_stage_count = orderedStages.length;
  result.store_capture.expected_stage_count = expectedCount;
  const manifest = {
    schema_version: 1,
    status: result.store_capture.status,
    classification: STORE_CAPTURE_CLASSIFICATION,
    submission_ready_store_asset: false,
    target_device_evidence: false,
    source_binding: result.store_capture.source_binding,
    capture: {
      surface: 'live_godot_web_export_in_headless_chrome',
      qa_mode: true,
      actual_gameplay: true,
      generated_or_mocked_frames: false,
      post_capture_scaling: false,
      compositing: false,
      viewport_width: STORE_VIEWPORT.width,
      viewport_height: STORE_VIEWPORT.height,
      device_scale_factor: 1,
    },
    smoke_evidence_manifest: 'infinidive-browser.json',
    smoke_report_status: result.status,
    semantic_touch_status: result.semantic_touch.status,
    expected_stage_count: expectedCount,
    captured_stage_count: orderedStages.length,
    stages: orderedStages,
    limitations: [
      'Browser capture is not native-iOS or physical-device evidence.',
      'Human visual review and release-candidate native recapture remain required before store submission.',
      'The artifact does not prove App Store Connect acceptance or approval.',
    ],
  };
  fs.writeFileSync(
    path.join(evidenceDir, STORE_CAPTURE_MANIFEST),
    `${JSON.stringify(manifest, null, 2)}\n`,
  );
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
      result.evidence_error = boundedDiagnosticText(error);
    }
  }
  persistStoreCaptureManifest(result);
  fs.writeFileSync(
    path.join(evidenceDir, 'infinidive-browser.json'),
    `${JSON.stringify(result, null, 2)}\n`,
  );
}

(async () => {
  const result = {
    url: sanitizedEvidenceUrl(targetUrl),
    qa_url: sanitizedEvidenceUrl(qaUrl.toString(), true),
    status: 'failed',
    console_messages: consoleMessages,
    page_errors: pageErrors,
    page_crashes: pageCrashes,
    network: {
      request_failures: requestFailures,
      critical_subresource_non_2xx: criticalSubresourceNon2xx,
      critical_subresource_errors: criticalSubresourceErrors,
    },
    diagnostic_limits: {
      maximum_entries_per_category: MAX_DIAGNOSTIC_ENTRIES,
      maximum_text_length: MAX_DIAGNOSTIC_TEXT_LENGTH,
      urls_strip_credentials_fragments_and_non_qa_queries: true,
    },
    semantic_touch: {
      status: 'in_progress',
      stage: 'launch',
      minimum_player_displacement_px: 12,
      snapshots: {},
      stage_screenshots: {},
      stage_screenshot_sha256: {},
    },
    ...(storeCaptureContract ? {
      store_capture: {
        status: 'in_progress',
        manifest: STORE_CAPTURE_MANIFEST,
        classification: STORE_CAPTURE_CLASSIFICATION,
        source_binding: {
          status: 'bound',
          commit: sourceCommit,
          repository: sourceRepository,
          run_id: Number(sourceRunId),
          run_attempt: Number(sourceRunAttempt),
          target_url: sanitizedEvidenceUrl(targetUrl),
          qa_url: sanitizedEvidenceUrl(qaUrl.toString(), true),
        },
        stages: [],
      },
    } : {}),
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
      viewport: BASE_VIEWPORT,
      hasTouch: true,
      isMobile: true,
      deviceScaleFactor: 1,
    });
    page = await context.newPage();
    page.on('console', (message) => {
      consoleMessageCount += 1;
      if (message.type() === 'error') sawConsoleError = true;
      appendBoundedDiagnostic(consoleMessages, {
        type: boundedDiagnosticText(message.type()),
        text: boundedDiagnosticText(message.text()),
      });
    });
    page.on('pageerror', (error) => {
      pageErrorCount += 1;
      appendBoundedDiagnostic(pageErrors, boundedDiagnosticText(error));
    });
    page.on('crash', () => {
      pageCrashCount += 1;
      appendBoundedDiagnostic(pageCrashes, {
        stage: boundedDiagnosticText(result.semantic_touch.stage),
      });
    });
    page.on('requestfailed', (request) => {
      const critical = isCriticalGameSubresource(request);
      requestFailureCount += 1;
      if (critical) criticalRequestFailureCount += 1;
      appendBoundedDiagnostic(requestFailures, {
        url: sanitizedEvidenceUrl(request.url()),
        method: boundedDiagnosticText(request.method()),
        resource_type: boundedDiagnosticText(request.resourceType()),
        error_text: boundedDiagnosticText(request.failure()?.errorText ?? 'unknown request failure'),
        critical,
      });
    });
    page.on('response', (subresourceResponse) => {
      const request = subresourceResponse.request();
      const status = subresourceResponse.status();
      if ((status < 200 || status >= 300) && isCriticalGameSubresource(request)) {
        const evidence = {
          url: sanitizedEvidenceUrl(subresourceResponse.url()),
          status,
          status_text: boundedDiagnosticText(subresourceResponse.statusText()),
          resource_type: boundedDiagnosticText(request.resourceType()),
        };
        criticalNon2xxCount += 1;
        appendBoundedDiagnostic(criticalSubresourceNon2xx, evidence);
        if (status < 200 || status >= 400) {
          criticalSubresourceErrorCount += 1;
          appendBoundedDiagnostic(criticalSubresourceErrors, evidence);
        }
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
    if (!runtime.status_hidden || runtime.canvas_width !== 540 || runtime.canvas_height !== 960) {
      throw new Error(`Godot canvas is not running at the coordinate contract's 540x960 viewport: ${JSON.stringify(runtime)}`);
    }
    result.runtime = runtime;

    result.semantic_touch.stage = 'nest_probe';
    await page.waitForFunction(
      () => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === 'infinidive.qa.v2'
          && Number.isInteger(state.revision)
          && state.view === 'nest';
      },
      null,
      { timeout: 15_000 },
    );
    const nestProbe = await qaSnapshot();
    assertProbe(nestProbe, 'Nest', 'nest');
    assertNestEnvelopeIsReadOnly(nestProbe, 'Fresh');
    if (nestProbe.run_generation !== 0) {
      throw new Error(`Nest QA probe did not start with a fresh run generation: ${JSON.stringify(nestProbe)}`);
    }
    if (nestProbe.persistence.tutorial_step_count !== 0
        || nestProbe.persistence.mutation_discovery_count !== 0
        || nestProbe.persistence.save_source !== 'default') {
      throw new Error(`Fresh Nest did not expose an empty default persistence baseline: ${JSON.stringify(nestProbe.persistence)}`);
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
      globalThis.__infinidiveQaTraceSignature = null;
      globalThis.__infinidiveQaTraceTimer = window.setInterval(() => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        if (!state || state.revision === globalThis.__infinidiveQaTraceRevision) return;
        globalThis.__infinidiveQaTraceRevision = state.revision;
        const milestone = {
          revision: state.revision,
          view: state.view,
          state: state.state ?? null,
          run_generation: state.run_generation,
          elapsed: state.elapsed ?? null,
          phase: state.phase ?? null,
          movement_observed: state.movement_observed ?? null,
          dash_count: state.dash_count ?? null,
          player_health_ratio: state.health?.player_ratio ?? null,
          target_health_ratio: state.health?.target_ratio ?? null,
          organ_id: state.organ?.id ?? null,
          organ_status: state.organ?.status ?? null,
          organ_health_ratio: state.organ?.health_ratio ?? null,
          ability_id: state.ability?.id ?? null,
          ability_status: state.ability?.status ?? null,
          boss_visual_state: state.boss_visual_state ?? null,
          mutation_offered_count: state.mutation?.offered_count ?? null,
          mutation_selected_count: state.mutation?.selected_count ?? null,
          last_selected_mutation_id: state.mutation?.last_selected_id ?? null,
          tutorial_step_count: state.persistence?.tutorial_step_count ?? null,
          mutation_discovery_count: state.persistence?.mutation_discovery_count ?? null,
          save_source: state.persistence?.save_source ?? null,
        };
        const signature = JSON.stringify([
          milestone.view,
          milestone.state,
          milestone.run_generation,
          milestone.phase,
          milestone.movement_observed,
          milestone.dash_count,
          milestone.organ_id,
          milestone.organ_status,
          milestone.ability_id,
          milestone.ability_status,
          milestone.boss_visual_state,
          milestone.mutation_offered_count,
          milestone.mutation_selected_count,
          milestone.last_selected_mutation_id,
          milestone.tutorial_step_count,
          milestone.mutation_discovery_count,
          milestone.save_source,
        ]);
        if (signature === globalThis.__infinidiveQaTraceSignature) return;
        globalThis.__infinidiveQaTraceSignature = signature;
        globalThis.__infinidiveQaTrace.push(milestone);
      }, 25);
    });

    const beforeInputPath = path.join(evidenceDir, 'infinidive-before-input.png');
    const beforeInput = await page.screenshot({ path: beforeInputPath, fullPage: true });
    result.semantic_touch.stage_screenshots.nest = path.basename(beforeInputPath);
    result.semantic_touch.stage_screenshot_sha256.nest = crypto
      .createHash('sha256')
      .update(beforeInput)
      .digest('hex');
    await captureStoreScreenshot(result, 'nest');
    result.semantic_touch.stage_screenshots.latest = 'infinidive-browser.png';
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
    await captureStageScreenshot(result, 'run-start-unarmed');

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
    await captureStageScreenshot(result, 'aion-spark-combat');

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

    result.semantic_touch.core_path = {
      expected_states: EXPECTED_CORE_PATH,
      selected_organ: 'hunter_eye',
      expected_ability: { id: 'homing_eye', status: 'degraded' },
      expected_visual_state: 'blinded_hunter_eye',
      input_coordinates: {
        dive: [476, 888],
        first_organ: [270, 421],
        first_mutation: [270, 360],
      },
      observed_states: ['EXTERIOR'],
    };

    result.semantic_touch.stage = 'breach_open_wait';
    const breachOpenProbe = await driveUntilState(
      cdp,
      'BREACH_OPEN',
      90_000,
      'Breach open',
    );
    assertRunTransition(dashDurableProbe, breachOpenProbe, 'Breach open', 'BREACH_OPEN', true);
    result.semantic_touch.snapshots.breach_open = breachOpenProbe;
    result.semantic_touch.core_path.observed_states.push('BREACH_OPEN');
    await captureStageScreenshot(result, 'breach-open');

    result.semantic_touch.stage = 'dive_tap';
    await page.touchscreen.tap(476, 888);
    const organSelectProbe = await waitForRunState(
      'ORGAN_SELECT',
      runStartProbe.run_generation,
      breachOpenProbe.revision,
      5_000,
      'Organ selection',
    );
    assertRunTransition(breachOpenProbe, organSelectProbe, 'Organ selection', 'ORGAN_SELECT', false);
    result.semantic_touch.snapshots.organ_select = organSelectProbe;
    result.semantic_touch.core_path.observed_states.push('ORGAN_SELECT');
    await captureStageScreenshot(result, 'organ-select');

    result.semantic_touch.stage = 'hunter_eye_tap';
    await page.touchscreen.tap(270, 421);
    const divingInProbe = await waitForRunState(
      'DIVING_IN',
      runStartProbe.run_generation,
      organSelectProbe.revision,
      5_000,
      'Dive in',
    );
    assertRunTransition(organSelectProbe, divingInProbe, 'Dive in', 'DIVING_IN', false);
    if (divingInProbe.organ.id !== 'hunter_eye' || divingInProbe.organ.status !== 'selected'
        || divingInProbe.ability.id !== 'homing_eye' || divingInProbe.ability.status !== 'active') {
      throw new Error(`The first rendered organ choice did not select the intact Hunter Eye: ${JSON.stringify(divingInProbe)}`);
    }
    result.semantic_touch.snapshots.diving_in = divingInProbe;
    result.semantic_touch.core_path.observed_states.push('DIVING_IN');

    result.semantic_touch.stage = 'internal_rooms_wait';
    const internalRoomsProbe = await driveUntilState(
      cdp,
      'INTERNAL_ROOMS',
      10_000,
      'Internal rooms',
    );
    assertRunTransition(divingInProbe, internalRoomsProbe, 'Internal rooms', 'INTERNAL_ROOMS', true);
    if (internalRoomsProbe.organ.id !== 'hunter_eye' || internalRoomsProbe.organ.status !== 'selected') {
      throw new Error(`Internal route lost the selected Hunter Eye: ${JSON.stringify(internalRoomsProbe.organ)}`);
    }
    result.semantic_touch.snapshots.internal_rooms = internalRoomsProbe;
    result.semantic_touch.core_path.observed_states.push('INTERNAL_ROOMS');
    await captureStageScreenshot(result, 'internal-route');

    result.semantic_touch.stage = 'organ_chamber_wait';
    const organChamberProbe = await driveUntilState(
      cdp,
      'ORGAN_CHAMBER',
      120_000,
      'Organ chamber',
    );
    assertRunTransition(internalRoomsProbe, organChamberProbe, 'Organ chamber', 'ORGAN_CHAMBER', true);
    if (organChamberProbe.organ.id !== 'hunter_eye' || organChamberProbe.organ.status !== 'selected'
        || organChamberProbe.organ.health_ratio === null
        || organChamberProbe.health.target_ratio === null) {
      throw new Error(`Hunter Eye chamber contract is incomplete: ${JSON.stringify(organChamberProbe)}`);
    }
    result.semantic_touch.snapshots.organ_chamber = organChamberProbe;
    result.semantic_touch.core_path.observed_states.push('ORGAN_CHAMBER');
    await captureStageScreenshot(result, 'organ-chamber');

    result.semantic_touch.stage = 'organ_destroyed_wait';
    const mutationChoiceProbe = await driveUntilState(
      cdp,
      'MUTATION_CHOICE',
      120_000,
      'Mutation choice',
    );
    assertRunTransition(organChamberProbe, mutationChoiceProbe, 'Mutation choice', 'MUTATION_CHOICE', false);
    if (mutationChoiceProbe.organ.id !== 'hunter_eye' || mutationChoiceProbe.organ.status !== 'destroyed'
        || mutationChoiceProbe.organ.health_ratio !== 0
        || mutationChoiceProbe.ability.id !== 'homing_eye'
        || mutationChoiceProbe.ability.status !== 'degraded'
        || mutationChoiceProbe.mutation.offered_count < 1
        || mutationChoiceProbe.mutation.offered_count > 3
        || mutationChoiceProbe.mutation.selected_count !== runStartProbe.mutation.selected_count) {
      throw new Error(`Organ destruction did not produce a legal mutation offer and degraded ability: ${JSON.stringify(mutationChoiceProbe)}`);
    }
    result.semantic_touch.snapshots.mutation_choice = mutationChoiceProbe;
    result.semantic_touch.core_path.observed_states.push('MUTATION_CHOICE');
    await captureStageScreenshot(result, 'mutation-choice');

    result.semantic_touch.stage = 'mutation_tap';
    await page.touchscreen.tap(270, 360);
    const divingOutProbe = await waitForRunState(
      'DIVING_OUT',
      runStartProbe.run_generation,
      mutationChoiceProbe.revision,
      5_000,
      'Dive out',
    );
    assertRunTransition(mutationChoiceProbe, divingOutProbe, 'Dive out', 'DIVING_OUT', false);
    if (divingOutProbe.mutation.selected_count !== mutationChoiceProbe.mutation.selected_count + 1
        || divingOutProbe.mutation.offered_count !== 0
        || typeof divingOutProbe.mutation.last_selected_id !== 'string'
        || divingOutProbe.mutation.last_selected_id.length < 1) {
      throw new Error(`Rendered mutation selection did not apply exactly one mutation: ${JSON.stringify(divingOutProbe.mutation)}`);
    }
    result.semantic_touch.snapshots.diving_out = divingOutProbe;
    result.semantic_touch.core_path.observed_states.push('DIVING_OUT');

    result.semantic_touch.stage = 'outside_return_wait';
    const outsideReturnProbe = await waitForRunState(
      'EXTERIOR',
      runStartProbe.run_generation,
      divingOutProbe.revision,
      8_000,
      'Outside return',
    );
    assertRunTransition(divingOutProbe, outsideReturnProbe, 'Outside return', 'EXTERIOR', true);
    if (outsideReturnProbe.phase !== runStartProbe.phase + 1
        || outsideReturnProbe.organ.id !== 'hunter_eye'
        || outsideReturnProbe.organ.status !== 'destroyed'
        || outsideReturnProbe.organ.health_ratio !== 0
        || outsideReturnProbe.ability.id !== 'homing_eye'
        || outsideReturnProbe.ability.status !== 'degraded'
        || outsideReturnProbe.boss_visual_state !== 'blinded_hunter_eye'
        || outsideReturnProbe.mutation.selected_count !== divingOutProbe.mutation.selected_count
        || outsideReturnProbe.mutation.last_selected_id !== divingOutProbe.mutation.last_selected_id
        || outsideReturnProbe.run_generation !== runStartProbe.run_generation) {
      throw new Error(`Outside return did not retain the Hunter Eye transformation and mutation: ${JSON.stringify(outsideReturnProbe)}`);
    }
    if (outsideReturnProbe.persistence.mutation_discovery_count
        !== nestProbe.persistence.mutation_discovery_count + 1) {
      throw new Error(`Mutation discovery did not persist before reload: ${JSON.stringify({
        before: nestProbe.persistence,
        after: outsideReturnProbe.persistence,
      })}`);
    }
    if (outsideReturnProbe.persistence.tutorial_step_count !== 8) {
      throw new Error(`Tutorial progress did not reach exactly eight core-path steps: ${JSON.stringify({
        before: nestProbe.persistence,
        after: outsideReturnProbe.persistence,
      })}`);
    }
    result.semantic_touch.snapshots.outside_return = outsideReturnProbe;
    result.semantic_touch.core_path.observed_states.push('EXTERIOR');
    if (JSON.stringify(result.semantic_touch.core_path.observed_states) !== JSON.stringify(EXPECTED_CORE_PATH)) {
      throw new Error(`Natural core path sequence is incomplete: ${JSON.stringify(result.semantic_touch.core_path.observed_states)}`);
    }
    result.semantic_touch.stage = 'outside_return_stability';
    await page.waitForFunction(
      ({ revision, runGeneration, selectedMutationId }) => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === 'infinidive.qa.v2'
          && state.view === 'run'
          && state.state === 'EXTERIOR'
          && state.run_generation === runGeneration
          && Number.isInteger(state.revision)
          && state.revision >= revision + 2
          && state.organ?.id === 'hunter_eye'
          && state.organ?.status === 'destroyed'
          && state.ability?.id === 'homing_eye'
          && state.ability?.status === 'degraded'
          && state.boss_visual_state === 'blinded_hunter_eye'
          && state.mutation?.last_selected_id === selectedMutationId;
      },
      {
        revision: outsideReturnProbe.revision,
        runGeneration: runStartProbe.run_generation,
        selectedMutationId: outsideReturnProbe.mutation.last_selected_id,
      },
      { timeout: 5_000 },
    );
    const outsideStableProbe = await qaSnapshot();
    assertRunProbe(outsideStableProbe, 'Stable outside return', 'EXTERIOR', true);
    if (outsideStableProbe.revision < outsideReturnProbe.revision + 2
        || outsideStableProbe.run_generation !== outsideReturnProbe.run_generation
        || outsideStableProbe.phase !== outsideReturnProbe.phase
        || outsideStableProbe.organ.id !== outsideReturnProbe.organ.id
        || outsideStableProbe.organ.status !== outsideReturnProbe.organ.status
        || outsideStableProbe.ability.id !== outsideReturnProbe.ability.id
        || outsideStableProbe.ability.status !== outsideReturnProbe.ability.status
        || outsideStableProbe.boss_visual_state !== outsideReturnProbe.boss_visual_state
        || outsideStableProbe.mutation.selected_count !== outsideReturnProbe.mutation.selected_count
        || outsideStableProbe.mutation.last_selected_id !== outsideReturnProbe.mutation.last_selected_id
        || outsideStableProbe.persistence.tutorial_step_count
          !== outsideReturnProbe.persistence.tutorial_step_count
        || outsideStableProbe.persistence.mutation_discovery_count
          !== outsideReturnProbe.persistence.mutation_discovery_count) {
      throw new Error(`Outside transformation was not stable for two revisions: ${JSON.stringify({
        first: outsideReturnProbe,
        stable: outsideStableProbe,
      })}`);
    }
    result.semantic_touch.snapshots.outside_return_stable = outsideStableProbe;
    await captureStoreScreenshot(result, 'outside_return');

    const explicitCorePath = [
      runStartProbe,
      breachOpenProbe,
      organSelectProbe,
      divingInProbe,
      internalRoomsProbe,
      organChamberProbe,
      mutationChoiceProbe,
      divingOutProbe,
      outsideReturnProbe,
    ];
    const explicitCoreStates = explicitCorePath.map((snapshot) => snapshot.state);
    if (JSON.stringify(explicitCoreStates) !== JSON.stringify(EXPECTED_CORE_PATH)) {
      throw new Error(`Synchronous QA milestones missed the natural core path: ${JSON.stringify({
        expected: EXPECTED_CORE_PATH,
        actual: explicitCoreStates,
      })}`);
    }
    let previousCoreRevision = runStartProbe.revision - 1;
    let previousCoreElapsed = runStartProbe.elapsed;
    for (const snapshot of explicitCorePath) {
      if (snapshot.view !== 'run' || snapshot.run_generation !== runStartProbe.run_generation
          || !Number.isInteger(snapshot.revision) || snapshot.revision <= previousCoreRevision
          || !Number.isFinite(snapshot.elapsed) || snapshot.elapsed < previousCoreElapsed) {
        throw new Error(`Synchronous core-path milestone left or restarted the run: ${JSON.stringify(snapshot)}`);
      }
      previousCoreRevision = snapshot.revision;
      previousCoreElapsed = snapshot.elapsed;
    }
    result.semantic_touch.synchronous_core_path = explicitCorePath.map((snapshot) => ({
      state: snapshot.state,
      revision: snapshot.revision,
      elapsed: snapshot.elapsed,
      phase: snapshot.phase,
      organ_id: snapshot.organ.id,
      organ_status: snapshot.organ.status,
      ability_id: snapshot.ability.id,
      ability_status: snapshot.ability.status,
      boss_visual_state: snapshot.boss_visual_state,
      mutation_offered_count: snapshot.mutation.offered_count,
      mutation_selected_count: snapshot.mutation.selected_count,
    }));

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
    if (!postInputRuntime.status_hidden || postInputRuntime.canvas_width !== 540
        || postInputRuntime.canvas_height !== 960) {
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
    result.semantic_touch.stage_screenshots.outside_return = path.basename(afterInputPath);
    const beforeInputSha256 = crypto.createHash('sha256').update(beforeInput).digest('hex');
    const afterInputSha256 = crypto.createHash('sha256').update(afterInput).digest('hex');
    result.semantic_touch.stage_screenshot_sha256.outside_return = afterInputSha256;
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
      if (snapshot.view !== 'run' || !Number.isFinite(snapshot.elapsed)
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
    if (sameRunTrace.length > 96) {
      throw new Error(`State-change QA trace exceeded its 96-milestone bound: ${sameRunTrace.length}`);
    }
    result.semantic_touch.qa_revision_trace = sameRunTrace;

    result.semantic_touch.stage = 'same_context_reload';
    const reloadMarker = crypto.randomBytes(16).toString('hex');
    const reloadMarkerSha256 = crypto.createHash('sha256').update(reloadMarker).digest('hex');
    await page.evaluate((marker) => {
      sessionStorage.setItem('__infinidiveQaSameContext', marker);
    }, reloadMarker);
    await page.waitForFunction(
      ({ schema, afterRevision, tutorialCount, discoveryCount }) => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === schema
          && state.view === 'run'
          && Number.isInteger(state.revision)
          && state.revision >= afterRevision + 20
          && state.persistence?.tutorial_step_count === tutorialCount
          && state.persistence?.mutation_discovery_count === discoveryCount;
      },
      {
        schema: QA_SCHEMA,
        afterRevision: outsideStableProbe.revision,
        tutorialCount: outsideStableProbe.persistence.tutorial_step_count,
        discoveryCount: outsideStableProbe.persistence.mutation_discovery_count,
      },
      { timeout: 15_000 },
    );
    const reloadResponse = await page.reload({ waitUntil: 'domcontentloaded', timeout: 30_000 });
    if (!reloadResponse || !reloadResponse.ok()) {
      throw new Error(`Same-context reload returned HTTP ${reloadResponse ? reloadResponse.status() : 'no response'}`);
    }
    await page.waitForFunction(
      () => document.getElementById('status')?.classList.contains('hidden') === true,
      null,
      { timeout: 90_000 },
    );
    await page.waitForFunction(
      () => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === 'infinidive.qa.v2'
          && Number.isInteger(state.revision)
          && state.view === 'nest';
      },
      null,
      { timeout: 15_000 },
    );
    const reloadedNestProbe = await qaSnapshot();
    assertProbe(reloadedNestProbe, 'Reloaded Nest', 'nest');
    assertNestEnvelopeIsReadOnly(reloadedNestProbe, 'Reloaded');
    const retainedReloadMarker = await page.evaluate(
      () => sessionStorage.getItem('__infinidiveQaSameContext'),
    );
    if (retainedReloadMarker !== reloadMarker) {
      throw new Error('The QA sessionStorage marker did not survive the same-context reload');
    }
    if (reloadedNestProbe.run_generation !== 0
        || reloadedNestProbe.persistence.save_source !== 'primary'
        || reloadedNestProbe.persistence.tutorial_step_count
          !== outsideStableProbe.persistence.tutorial_step_count
        || reloadedNestProbe.persistence.mutation_discovery_count
          !== outsideStableProbe.persistence.mutation_discovery_count) {
      throw new Error(`Reloaded Nest did not restore the exact persisted QA aggregate counts: ${JSON.stringify({
        before_reload: outsideStableProbe.persistence,
        after_reload: reloadedNestProbe.persistence,
        run_generation: reloadedNestProbe.run_generation,
      })}`);
    }
    result.semantic_touch.snapshots.reloaded_nest = reloadedNestProbe;
    result.semantic_touch.reload_proof = {
      same_browser_context: true,
      session_storage_marker_retained: true,
      marker_sha256: reloadMarkerSha256,
      query_retained: new URL(page.url()).searchParams.get('infinidive_qa') === '1',
      http_status: reloadResponse.status(),
      run_generation_reset_to_zero: true,
      save_source: reloadedNestProbe.persistence.save_source,
      tutorial_step_count: reloadedNestProbe.persistence.tutorial_step_count,
      mutation_discovery_count: reloadedNestProbe.persistence.mutation_discovery_count,
      pre_reload_persistence_stable_revisions: 20,
    };
    if (!result.semantic_touch.reload_proof.query_retained) {
      throw new Error(`QA query flag was lost across reload: ${page.url()}`);
    }
    result.semantic_touch.stage = 'runtime_error_gate';
    result.console_message_count = consoleMessageCount;
    result.page_error_count = pageErrorCount;
    result.page_crash_count = pageCrashCount;
    result.network.request_failure_count = requestFailureCount;
    result.network.critical_request_failure_count = criticalRequestFailureCount;
    result.network.ignored_request_failure_count = requestFailureCount - criticalRequestFailureCount;
    result.network.critical_non_2xx_count = criticalNon2xxCount;
    result.network.critical_subresource_error_count = criticalSubresourceErrorCount;
    if (criticalRequestFailureCount || criticalSubresourceErrorCount) {
      throw new Error('A critical game subresource failed to load');
    }
    if (pageCrashCount) {
      throw new Error('The game page crashed during the semantic touch smoke');
    }
    if (pageErrorCount || sawConsoleError) {
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
      final_screenshot_stage: 'outside_return',
    };
    result.semantic_touch.status = 'passed';
    result.semantic_touch.stage = 'complete';
    result.semantic_touch.qa_revision_trace = sameRunTrace;
    result.semantic_touch.same_run = {
      method: 'bounded state-change milestones with stable view/run_generation and monotonic revision/elapsed',
      run_generation: runStartProbe.run_generation,
      first_revision: runStartProbe.revision,
      last_revision: outsideStableProbe.revision,
      first_elapsed: runStartProbe.elapsed,
      last_elapsed: outsideStableProbe.elapsed,
      milestone_count: sameRunTrace.length,
      maximum_milestones: 96,
      natural_core_path_observed: true,
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
      natural_outside_inside_outside_path: true,
      hunter_eye_selected_and_destroyed: true,
      homing_eye_degraded: true,
      blinded_hunter_eye_render_state: true,
      outside_transformation_stable_for_two_revisions: true,
      mutation_selected_through_rendered_overlay: true,
      same_context_reload: true,
      persistence_counts_restored_exactly: true,
      reloaded_save_source_primary: true,
      qa_contract_exact_key_whitelist: true,
      state_change_trace_bounded: true,
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
        result.semantic_touch.probe_evidence_error = boundedDiagnosticText(probeError);
      }
    }
    result.console_message_count = consoleMessageCount;
    result.page_error_count = pageErrorCount;
    result.page_crash_count = pageCrashCount;
    result.network.request_failure_count = requestFailureCount;
    result.network.critical_request_failure_count = criticalRequestFailureCount;
    result.network.ignored_request_failure_count = requestFailureCount - criticalRequestFailureCount;
    result.network.critical_non_2xx_count = criticalNon2xxCount;
    result.network.critical_subresource_error_count = criticalSubresourceErrorCount;
    result.failure = boundedDiagnosticText(error);
    await persistEvidence(result);
    process.stderr.write(`${JSON.stringify(result, null, 2)}\n`);
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close();
  }
})();
