'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const REPOSITORY_ROOT = path.resolve(__dirname, '..', '..');
const CAPTURE_MANIFEST_PATH = path.join(
  REPOSITORY_ROOT,
  'infinidive-game',
  'assets',
  'store',
  'gameplay',
  'capture-manifest.json',
);
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const LOWERCASE_SHA256 = /^[0-9a-f]{64}$/;

class StageScreenshotValidationError extends Error {}

function fail(message) {
  throw new StageScreenshotValidationError(message);
}

function requireObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object`);
  }
  return value;
}

function assertExactKeys(value, expectedKeys, label) {
  const actual = Object.keys(requireObject(value, label)).sort();
  const expected = [...expectedKeys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    fail(`${label} keys differ from the capture contract: ${JSON.stringify({ expected, actual })}`);
  }
}

function parsePngDimensions(bytes, label) {
  if (!Buffer.isBuffer(bytes) || bytes.length < 33 || !bytes.subarray(0, 8).equals(PNG_SIGNATURE)) {
    fail(`${label} is not a complete PNG header`);
  }
  if (bytes.readUInt32BE(8) !== 13 || bytes.subarray(12, 16).toString('ascii') !== 'IHDR') {
    fail(`${label} does not begin with a valid PNG IHDR chunk`);
  }
  const width = bytes.readUInt32BE(16);
  const height = bytes.readUInt32BE(20);
  if (width < 1 || height < 1) fail(`${label} has invalid PNG dimensions`);
  return { width, height };
}

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function requireSafeFileName(fileName, label) {
  if (typeof fileName !== 'string'
      || fileName.length === 0
      || fileName !== path.basename(fileName)
      || fileName.includes('/')
      || fileName.includes('\\')) {
    fail(`${label} must be a plain file name without path components`);
  }
  return fileName;
}

function readJson(jsonPath, label) {
  let bytes;
  try {
    bytes = fs.readFileSync(jsonPath, 'utf8');
  } catch (error) {
    fail(`cannot read ${label} ${jsonPath}: ${error.message}`);
  }
  try {
    return JSON.parse(bytes);
  } catch (error) {
    fail(`cannot parse ${label} ${jsonPath}: ${error.message}`);
  }
}

function loadContract() {
  const manifest = requireObject(readJson(CAPTURE_MANIFEST_PATH, 'capture manifest'), 'capture manifest');
  if (manifest.schema_version !== 4) {
    fail(`capture manifest schema_version must be 4, got ${JSON.stringify(manifest.schema_version)}`);
  }
  const plannedCapture = requireObject(manifest.planned_capture, 'planned_capture');
  const contract = requireObject(plannedCapture.ci_stage_screenshots, 'planned_capture.ci_stage_screenshots');
  if (contract.classification !== 'current_source_ci_browser_qa_evidence_not_submission_ready_store_asset') {
    fail('CI stage screenshot classification is missing or unsafe');
  }
  if (contract.evidence_manifest !== 'infinidive-browser.json') {
    fail('CI stage screenshot evidence_manifest must be infinidive-browser.json');
  }
  const expectedImage = requireObject(contract.expected_image, 'expected_image');
  if (expectedImage.format !== 'PNG'
      || !Number.isInteger(expectedImage.width)
      || !Number.isInteger(expectedImage.height)
      || expectedImage.width < 1
      || expectedImage.height < 1
      || expectedImage.device_scale_factor !== 1) {
    fail('expected_image must define positive integer PNG dimensions at device scale factor 1');
  }
  const stageFiles = requireObject(contract.stage_files, 'stage_files');
  if (Object.keys(stageFiles).length === 0) fail('stage_files must not be empty');
  for (const [stage, fileName] of Object.entries(stageFiles)) {
    if (!/^[a-z0-9_-]+$/.test(stage)) fail(`unsafe stage key: ${JSON.stringify(stage)}`);
    requireSafeFileName(fileName, `stage_files.${stage}`);
    if (!fileName.endsWith('.png')) fail(`stage_files.${stage} must name a PNG`);
  }
  if (new Set(Object.values(stageFiles)).size !== Object.keys(stageFiles).length) {
    fail('canonical stage_files must use a distinct PNG for every stage');
  }
  const aliases = requireObject(contract.screenshot_aliases, 'screenshot_aliases');
  for (const [alias, targetStage] of Object.entries(aliases)) {
    if (!/^[a-z0-9_-]+$/.test(alias)) fail(`unsafe screenshot alias: ${JSON.stringify(alias)}`);
    if (!Object.hasOwn(stageFiles, targetStage)) {
      fail(`screenshot alias ${alias} targets unknown stage ${JSON.stringify(targetStage)}`);
    }
  }
  return contract;
}

function readRegularFile(evidenceDirectory, fileName, label) {
  requireSafeFileName(fileName, label);
  const filePath = path.join(evidenceDirectory, fileName);
  let stat;
  try {
    stat = fs.lstatSync(filePath);
  } catch (error) {
    fail(`cannot inspect ${label} ${filePath}: ${error.message}`);
  }
  if (!stat.isFile() || stat.isSymbolicLink()) fail(`${label} must be a regular, non-symlink file`);
  try {
    return fs.readFileSync(filePath);
  } catch (error) {
    fail(`cannot read ${label} ${filePath}: ${error.message}`);
  }
}

function validateEvidence(evidenceDirectory, contract) {
  const resolvedDirectory = path.resolve(evidenceDirectory);
  let directoryStat;
  try {
    directoryStat = fs.statSync(resolvedDirectory);
  } catch (error) {
    fail(`cannot inspect smoke-evidence directory ${resolvedDirectory}: ${error.message}`);
  }
  if (!directoryStat.isDirectory()) fail(`smoke-evidence path is not a directory: ${resolvedDirectory}`);

  const reportFileName = requireSafeFileName(contract.evidence_manifest, 'evidence_manifest');
  const report = requireObject(
    readJson(path.join(resolvedDirectory, reportFileName), 'smoke report'),
    'smoke report',
  );
  if (report.status !== 'passed') fail(`smoke report status must be passed, got ${JSON.stringify(report.status)}`);

  const semanticTouch = requireObject(report.semantic_touch, 'semantic_touch');
  if (semanticTouch.status !== 'passed') {
    fail(`semantic_touch.status must be passed, got ${JSON.stringify(semanticTouch.status)}`);
  }
  const runtime = requireObject(report.runtime, 'runtime');
  const expectedImage = contract.expected_image;
  if (runtime.canvas_width !== expectedImage.width || runtime.canvas_height !== expectedImage.height) {
    fail(`runtime canvas dimensions differ from the capture contract: ${JSON.stringify({
      expected: [expectedImage.width, expectedImage.height],
      actual: [runtime.canvas_width, runtime.canvas_height],
    })}`);
  }

  const stageFiles = contract.stage_files;
  const aliases = contract.screenshot_aliases;
  const stageKeys = Object.keys(stageFiles);
  const screenshotMap = requireObject(semanticTouch.stage_screenshots, 'semantic_touch.stage_screenshots');
  const hashMap = requireObject(semanticTouch.stage_screenshot_sha256, 'semantic_touch.stage_screenshot_sha256');
  assertExactKeys(screenshotMap, [...stageKeys, ...Object.keys(aliases)], 'semantic_touch.stage_screenshots');
  assertExactKeys(hashMap, stageKeys, 'semantic_touch.stage_screenshot_sha256');

  for (const [alias, targetStage] of Object.entries(aliases)) {
    if (screenshotMap[alias] !== stageFiles[targetStage]) {
      fail(`screenshot alias ${alias} must point to ${stageFiles[targetStage]}`);
    }
  }

  const validatedStages = [];
  for (const stage of stageKeys) {
    const expectedFileName = stageFiles[stage];
    if (screenshotMap[stage] !== expectedFileName) {
      fail(`stage ${stage} must map to ${expectedFileName}, got ${JSON.stringify(screenshotMap[stage])}`);
    }
    const expectedHash = hashMap[stage];
    if (typeof expectedHash !== 'string' || !LOWERCASE_SHA256.test(expectedHash)) {
      fail(`stage ${stage} must record a lowercase SHA-256 digest`);
    }
    const bytes = readRegularFile(resolvedDirectory, expectedFileName, `stage ${stage}`);
    const actualHash = sha256(bytes);
    if (actualHash !== expectedHash) {
      fail(`stage ${stage} SHA-256 mismatch: expected ${expectedHash}, got ${actualHash}`);
    }
    const dimensions = parsePngDimensions(bytes, `stage ${stage}`);
    if (dimensions.width !== expectedImage.width || dimensions.height !== expectedImage.height) {
      fail(`stage ${stage} dimensions differ from the capture contract: ${JSON.stringify({
        expected: [expectedImage.width, expectedImage.height],
        actual: [dimensions.width, dimensions.height],
      })}`);
    }
    validatedStages.push({
      stage,
      file: expectedFileName,
      sha256: actualHash,
      width: dimensions.width,
      height: dimensions.height,
    });
  }

  return {
    status: 'passed',
    classification: contract.classification,
    submission_ready_store_asset: false,
    source_binding: 'workflow_run_and_checked_out_commit_required',
    evidence_directory: resolvedDirectory,
    validated_stage_count: validatedStages.length,
    stages: validatedStages,
  };
}

function runSelfTest() {
  const header = Buffer.alloc(33);
  PNG_SIGNATURE.copy(header, 0);
  header.writeUInt32BE(13, 8);
  header.write('IHDR', 12, 4, 'ascii');
  header.writeUInt32BE(540, 16);
  header.writeUInt32BE(960, 20);

  assert.deepEqual(parsePngDimensions(header, 'in-memory fixture'), { width: 540, height: 960 });
  assert.equal(sha256(Buffer.from('infinidive-stage-validator')), '6fc9582390f5bec8988e2d4f1e2bcb4c0a2e598d37b0c2e4d0800b78906b7abc');
  assert.doesNotThrow(() => assertExactKeys({ nest: true, outside_return: true }, ['outside_return', 'nest'], 'fixture keys'));
  assert.throws(
    () => assertExactKeys({ nest: true, extra: true }, ['nest'], 'fixture keys'),
    StageScreenshotValidationError,
  );
  assert.throws(() => parsePngDimensions(Buffer.from('not a png'), 'bad fixture'), StageScreenshotValidationError);
  assert.throws(() => requireSafeFileName('../escape.png', 'fixture file'), StageScreenshotValidationError);
  assert.equal(loadContract().classification, 'current_source_ci_browser_qa_evidence_not_submission_ready_store_asset');
  process.stdout.write('stage screenshot validator self-test: PASS\n');
}

function main(argv) {
  if (argv.length === 1 && argv[0] === '--self-test') {
    runSelfTest();
    return;
  }
  if (argv.length !== 1) {
    process.stderr.write('Usage: node .github/scripts/validate_stage_screenshots.cjs <smoke-evidence-directory>\n');
    process.stderr.write('       node .github/scripts/validate_stage_screenshots.cjs --self-test\n');
    process.exitCode = 2;
    return;
  }
  const result = validateEvidence(argv[0], loadContract());
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

try {
  main(process.argv.slice(2));
} catch (error) {
  if (error instanceof StageScreenshotValidationError) {
    process.stderr.write(`stage screenshot validation failed: ${error.message}\n`);
    process.exitCode = 1;
  } else {
    throw error;
  }
}
