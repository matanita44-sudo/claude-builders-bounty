'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const targetUrlArgument = process.argv[2];
const evidenceDirArgument = process.argv[3];
const coordinateSelfTest = targetUrlArgument === '--coordinate-self-test' && process.argv.length === 3;
const chromeBin = process.env.INFINIDIVE_CHROME_BIN;
const playwrightRoot = process.env.INFINIDIVE_PLAYWRIGHT_ROOT;
const ffmpegBin = process.env.INFINIDIVE_FFMPEG_BIN || 'ffmpeg';
const ffprobeBin = process.env.INFINIDIVE_FFPROBE_BIN || 'ffprobe';

if (!coordinateSelfTest && (!targetUrlArgument || !evidenceDirArgument || !chromeBin || !playwrightRoot)) {
  throw new Error(
    'Bright trailer capture requires URL, evidence directory, Chrome, and Playwright root',
  );
}

const REPOSITORY_ROOT = path.resolve(__dirname, '..', '..');
const CONTRACT_PATH = path.join(
  REPOSITORY_ROOT,
  'infinidive-game',
  'assets',
  'store',
  'gameplay',
  'bright-trailer-capture-contract.json',
);
const QA_SCHEMA = 'infinidive.qa.v2';
const EXPECTED_CLASSIFICATION =
  'current_source_ci_browser_gameplay_trailer_review_candidate_not_apple_submission_evidence';
const ACTIVE_INPUT_STATES = new Set(['EXTERIOR', 'BREACH_OPEN', 'INTERNAL_ROOMS', 'ORGAN_CHAMBER', 'CORE']);
const TERMINAL_STATES = new Set(['DEAD', 'VICTORY']);
const LOGICAL_VIEWPORT = Object.freeze({ width: 540, height: 960 });
const MAX_DIAGNOSTICS = 128;

const chromium = coordinateSelfTest
  ? null
  : require(path.join(playwrightRoot, 'node_modules', 'playwright-core')).chromium;

function sha256Bytes(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function sha256File(filePath) {
  return sha256Bytes(fs.readFileSync(filePath));
}

function finiteNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

function assertSafeBasename(value, suffix, label) {
  if (typeof value !== 'string' || value !== path.basename(value) || !value.endsWith(suffix)) {
    throw new Error(`${label} is not a safe ${suffix} basename: ${JSON.stringify(value)}`);
  }
}

function assertSha256(value, label) {
  if (typeof value !== 'string' || !/^[0-9a-f]{64}$/.test(value)) {
    throw new Error(`${label} is not a lowercase SHA-256 digest`);
  }
}

function repositoryFile(relativePath, label) {
  if (typeof relativePath !== 'string' || relativePath.length < 1
      || path.isAbsolute(relativePath) || relativePath.includes('\\')) {
    throw new Error(`${label} is not a repository-relative path`);
  }
  const normalized = path.normalize(relativePath);
  const resolved = path.resolve(REPOSITORY_ROOT, normalized);
  if (normalized !== relativePath || normalized === '..' || normalized.startsWith(`..${path.sep}`)
      || resolved === REPOSITORY_ROOT || !resolved.startsWith(`${REPOSITORY_ROOT}${path.sep}`)) {
    throw new Error(`${label} escapes the repository: ${JSON.stringify(relativePath)}`);
  }
  if (!fs.statSync(resolved, { throwIfNoEntry: false })?.isFile()) {
    throw new Error(`${label} is missing: ${relativePath}`);
  }
  return resolved;
}

function sanitizedUrl(rawUrl, includeQa = false) {
  const parsed = new URL(rawUrl);
  parsed.username = '';
  parsed.password = '';
  parsed.hash = '';
  parsed.search = includeQa ? '?infinidive_qa=1' : '';
  return parsed.toString();
}

function sourceBinding(targetUrl) {
  const commit = process.env.INFINIDIVE_SOURCE_COMMIT ?? process.env.GITHUB_SHA ?? '';
  const repository = process.env.INFINIDIVE_SOURCE_REPOSITORY ?? process.env.GITHUB_REPOSITORY ?? '';
  const runId = process.env.INFINIDIVE_SOURCE_RUN_ID ?? process.env.GITHUB_RUN_ID ?? '';
  const runAttempt = process.env.INFINIDIVE_SOURCE_RUN_ATTEMPT ?? process.env.GITHUB_RUN_ATTEMPT ?? '';
  if (!/^[0-9a-f]{40,64}$/.test(commit)
      || !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository)
      || !/^\d+$/.test(runId) || Number(runId) < 1
      || !/^\d+$/.test(runAttempt) || Number(runAttempt) < 1) {
    throw new Error('Bright trailer capture requires valid commit/repository/run source binding');
  }
  return {
    status: 'bound',
    commit,
    repository,
    run_id: Number(runId),
    run_attempt: Number(runAttempt),
    target_url: sanitizedUrl(targetUrl),
    qa_url: sanitizedUrl(targetUrl, true),
  };
}

function loadContract() {
  const bytes = fs.readFileSync(CONTRACT_PATH);
  const contract = JSON.parse(bytes.toString('utf8'));
  if (contract.schema_version !== 2
      || contract.classification !== EXPECTED_CLASSIFICATION
      || contract.evidence_manifest !== 'infinidive-bright-trailer.json'
      || !contract.capture || !contract.deliverable || !contract.audio || !contract.semantic_flow
      || !contract.editing || !contract.visual_validation) {
    throw new Error('Bright trailer contract is missing or has an unexpected schema');
  }
  const { capture, deliverable, semantic_flow: semanticFlow, editing } = contract;
  if (!Number.isInteger(capture.viewport_width) || !Number.isInteger(capture.viewport_height)
      || capture.viewport_width < 1 || capture.viewport_height < 1
      || capture.device_scale_factor !== 1 || capture.has_touch !== true
      || capture.is_mobile !== true || capture.actual_gameplay !== true
      || capture.generated_or_mocked_gameplay !== false
      || capture.debug_state_injection !== false || capture.save_manipulation !== false
      || capture.browser_audio_captured !== false
      || typeof capture.browser_audio_disclosure !== 'string'
      || !capture.browser_audio_disclosure.includes('not event-synchronous')) {
    throw new Error('Bright trailer capture contract permits an unsafe capture surface');
  }
  if (deliverable.width !== capture.viewport_width || deliverable.height !== capture.viewport_height
      || !finiteNumber(deliverable.minimum_duration_seconds)
      || !finiteNumber(deliverable.maximum_duration_seconds)
      || deliverable.minimum_duration_seconds < 15
      || deliverable.maximum_duration_seconds > 30
      || deliverable.minimum_duration_seconds >= deliverable.maximum_duration_seconds
      || !finiteNumber(deliverable.maximum_frame_rate)
      || deliverable.maximum_frame_rate > 30
      || typeof deliverable.audio_policy !== 'string'
      || !deliverable.audio_policy.includes('Exactly one AAC (MP4) or Opus (WebM) track')
      || !deliverable.audio_policy.includes('not live-captured or event-synchronous')) {
    throw new Error('Bright trailer deliverable contract is invalid');
  }
  const profileKeys = deliverable.accepted_profiles?.map(
    (profile) => `${profile.container}/${profile.video_codec}/${profile.pixel_format}/${profile.audio_codec}`,
  );
  if (JSON.stringify(profileKeys) !== JSON.stringify([
    'mp4/h264/yuv420p/aac',
    'webm/vp9/yuv420p/opus',
  ])) {
    throw new Error('Bright trailer codec profiles do not require the supported audio codecs');
  }
  assertSafeBasename(capture.raw_file, '.webm', 'Raw trailer file');
  assertSafeBasename(deliverable.preferred_file, '.mp4', 'Preferred trailer file');
  const { audio } = contract;
  const sourceAsset = audio.source_asset;
  const provenance = audio.provenance;
  const mux = audio.mux;
  const audioValidation = audio.validation;
  if (audio.track_count !== 1 || !sourceAsset || !provenance || !mux || !audioValidation
      || sourceAsset.format !== 'wav' || sourceAsset.codec !== 'pcm_s16le'
      || sourceAsset.sample_rate !== 48000 || sourceAsset.channels !== 2
      || sourceAsset.duration_seconds !== 30.0 || !Number.isInteger(sourceAsset.bytes)
      || sourceAsset.bytes < 1
      || provenance.kind !== 'deterministic_offline_mix_of_project_generated_runtime_music'
      || provenance.project_owned !== true || provenance.external_samples !== false
      || provenance.browser_captured !== false || provenance.event_synchronized !== false
      || provenance.music_only !== true
      || !Array.isArray(provenance.source_files) || provenance.source_files.length < 3
      || mux.timing !== 'trim_source_music_to_edited_video_duration'
      || mux.video_mode !== 'stream_copy_after_hard_cut_video_encode'
      || mux.require_identical_video_packet_sha256_before_and_after_audio_mux !== true
      || mux.encoded_sample_rate !== 48000 || mux.encoded_channels !== 2
      || !finiteNumber(audioValidation.minimum_mean_volume_dbfs)
      || !finiteNumber(audioValidation.minimum_peak_volume_dbfs)
      || !finiteNumber(audioValidation.maximum_peak_volume_dbfs)
      || audioValidation.minimum_mean_volume_dbfs >= audioValidation.minimum_peak_volume_dbfs
      || audioValidation.minimum_peak_volume_dbfs >= audioValidation.maximum_peak_volume_dbfs
      || audioValidation.maximum_peak_volume_dbfs >= 0) {
    throw new Error('Bright trailer audio contract is invalid or overclaims browser capture');
  }
  assertSafeBasename(sourceAsset.evidence_file, '.wav', 'Audio evidence file');
  assertSha256(sourceAsset.sha256, 'Audio source asset hash');
  const audioSourcePath = repositoryFile(sourceAsset.repository_file, 'Audio source asset');
  if (fs.statSync(audioSourcePath).size !== sourceAsset.bytes
      || sha256File(audioSourcePath) !== sourceAsset.sha256) {
    throw new Error('Bright trailer audio source asset differs from its contract hash/size');
  }
  const sourcePaths = new Set();
  for (const source of provenance.source_files) {
    assertSha256(source?.sha256, 'Audio provenance source hash');
    if (sourcePaths.has(source.repository_file)) {
      throw new Error(`Duplicate audio provenance source: ${source.repository_file}`);
    }
    sourcePaths.add(source.repository_file);
    const sourcePath = repositoryFile(source.repository_file, 'Audio provenance source');
    if (sha256File(sourcePath) !== source.sha256) {
      throw new Error(`Audio provenance source hash mismatch: ${source.repository_file}`);
    }
  }
  if (!Array.isArray(semanticFlow.expected_states) || semanticFlow.expected_states.length < 2
      || !Array.isArray(semanticFlow.milestones) || semanticFlow.milestones.length < 2
      || !Array.isArray(editing.ordered_segments) || editing.ordered_segments.length < 1
      || editing.kind !== 'hard_cuts_from_one_continuous_actual_gameplay_recording'
      || editing.speed_multiplier !== 1.0 || editing.overlays !== false
      || editing.drawn_text !== false || editing.fabricated_ui !== false
      || editing.compositing !== false || editing.cropping !== false
      || editing.scaling !== false || editing.generated_gameplay_frames !== false) {
    throw new Error('Bright trailer semantic/editing contract is unsafe');
  }
  const milestoneKeys = new Set();
  for (const milestone of semanticFlow.milestones) {
    if (typeof milestone.key !== 'string' || !/^[a-z0-9_-]+$/.test(milestone.key)
        || milestoneKeys.has(milestone.key) || !milestone.required_qa
        || typeof milestone.required_qa !== 'object' || Array.isArray(milestone.required_qa)) {
      throw new Error(`Invalid bright trailer milestone: ${JSON.stringify(milestone)}`);
    }
    milestoneKeys.add(milestone.key);
  }
  for (const segment of editing.ordered_segments) {
    if (typeof segment.key !== 'string' || !/^[a-z0-9_-]+$/.test(segment.key)
        || !milestoneKeys.has(segment.start_anchor) || !milestoneKeys.has(segment.end_anchor)
        || !finiteNumber(segment.start_offset_seconds) || !finiteNumber(segment.end_offset_seconds)) {
      throw new Error(`Invalid bright trailer edit segment: ${JSON.stringify(segment)}`);
    }
  }
  return { contract, contractSha256: sha256Bytes(bytes), audioSourcePath };
}

function run(command, args, label, allowFailure = false) {
  const completed = spawnSync(command, args, {
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
  if (completed.error || completed.status !== 0) {
    if (allowFailure) return completed;
    throw new Error(
      `${label} failed (${completed.status ?? 'spawn'}): ${completed.error?.message ?? completed.stderr}`,
    );
  }
  return completed;
}

function ffprobe(filePath) {
  return JSON.parse(run(
    ffprobeBin,
    [
      '-v', 'error',
      '-show_entries',
      'format=format_name,duration,size:stream=index,codec_type,codec_name,profile,width,height,pix_fmt,avg_frame_rate,r_frame_rate,sample_fmt,sample_rate,channels,channel_layout,duration',
      '-of', 'json',
      filePath,
    ],
    `FFprobe ${path.basename(filePath)}`,
  ).stdout);
}

function videoStream(probe) {
  return probe.streams?.find((stream) => stream.codec_type === 'video') ?? null;
}

function audioStreams(probe) {
  return probe.streams?.filter((stream) => stream.codec_type === 'audio') ?? [];
}

function audioLevels(filePath, label) {
  const levelOutput = run(
    ffmpegBin,
    [
      '-hide_banner', '-nostats', '-i', filePath,
      '-map', '0:a:0', '-af', 'volumedetect', '-f', 'null', '-',
    ],
    label,
  ).stderr;
  const meanMatch = /mean_volume:\s*(-?(?:\d+(?:\.\d+)?|inf))\s*dB/i.exec(levelOutput);
  const peakMatch = /max_volume:\s*(-?(?:\d+(?:\.\d+)?|inf))\s*dB/i.exec(levelOutput);
  return {
    meanVolumeDbfs: Number(meanMatch?.[1]),
    peakVolumeDbfs: Number(peakMatch?.[1]),
  };
}

function assertAudioLevels(levels, validation, label) {
  if (!finiteNumber(levels.meanVolumeDbfs) || !finiteNumber(levels.peakVolumeDbfs)
      || levels.meanVolumeDbfs < validation.minimum_mean_volume_dbfs
      || levels.peakVolumeDbfs < validation.minimum_peak_volume_dbfs
      || levels.peakVolumeDbfs > validation.maximum_peak_volume_dbfs) {
    throw new Error(`${label} is silent or outside its level contract: ${JSON.stringify(levels)}`);
  }
}

function validateAudioSource(audioSourcePath, audioContract) {
  const probe = ffprobe(audioSourcePath);
  const streams = audioStreams(probe);
  const audio = streams[0];
  const duration = Number(probe.format?.duration);
  if (streams.length !== 1 || probe.streams?.some((stream) => stream.codec_type === 'video')
      || !String(probe.format?.format_name ?? '').split(',').includes('wav')
      || audio?.codec_name !== audioContract.source_asset.codec
      || audio?.sample_fmt !== 's16'
      || Number(audio?.sample_rate) !== audioContract.source_asset.sample_rate
      || audio?.channels !== audioContract.source_asset.channels
      || !finiteNumber(duration)
      || Math.abs(duration - audioContract.source_asset.duration_seconds) > 0.001) {
    throw new Error(`Bright trailer audio source media contract failed: ${JSON.stringify(probe)}`);
  }
  const levels = audioLevels(audioSourcePath, 'Bright trailer source-audio level analysis');
  assertAudioLevels(levels, audioContract.validation, 'Bright trailer audio source');
  return { probe, duration, stream: audio, ...levels };
}

function videoPacketSha256(filePath) {
  const output = run(
    ffmpegBin,
    [
      '-hide_banner', '-v', 'error', '-i', filePath,
      '-map', '0:v:0', '-c:v', 'copy', '-f', 'hash', '-hash', 'sha256', '-',
    ],
    `Video packet hash ${path.basename(filePath)}`,
  ).stdout.trim();
  const match = /^SHA256=([0-9a-f]{64})$/.exec(output);
  if (!match) throw new Error(`FFmpeg returned an invalid video packet hash: ${JSON.stringify(output)}`);
  return match[1];
}

function valueAtPath(value, dottedPath) {
  return dottedPath.split('.').reduce(
    (cursor, segment) => (cursor && typeof cursor === 'object' ? cursor[segment] : undefined),
    value,
  );
}

function assertRequiredQa(snapshot, requiredQa, label) {
  if (!snapshot || snapshot.schema !== QA_SCHEMA || snapshot.view !== 'run'
      || !Number.isInteger(snapshot.revision) || !Number.isInteger(snapshot.run_generation)
      || !finiteNumber(snapshot.elapsed)) {
    throw new Error(`${label} does not expose a valid live-run QA snapshot: ${JSON.stringify(snapshot)}`);
  }
  for (const [field, expected] of Object.entries(requiredQa)) {
    const actual = valueAtPath(snapshot, field);
    if (actual !== expected) {
      throw new Error(
        `${label} expected QA ${field}=${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
      );
    }
  }
}

function qaEvidence(snapshot) {
  return {
    schema: snapshot.schema,
    revision: snapshot.revision,
    run_generation: snapshot.run_generation,
    view: snapshot.view,
    state: snapshot.state,
    elapsed: snapshot.elapsed,
    phase: snapshot.phase,
    controls_active: snapshot.controls_active,
    movement_observed: snapshot.movement_observed,
    player_position: snapshot.player_position,
    health: snapshot.health,
    organ: snapshot.organ,
    ability: snapshot.ability,
    boss_visual_state: snapshot.boss_visual_state,
    mutation: snapshot.mutation,
  };
}

function actualPoint(logicalPoint, viewport) {
  // Godot keeps the 540x960 game aspect inside taller phone canvases. Browser
  // touch coordinates must include the resulting letterbox offset; scaling X
  // and Y independently targets the lower cyan bar on 886x1920 captures.
  const scale = Math.min(
    viewport.width / LOGICAL_VIEWPORT.width,
    viewport.height / LOGICAL_VIEWPORT.height,
  );
  const offsetX = (viewport.width - LOGICAL_VIEWPORT.width * scale) / 2;
  const offsetY = (viewport.height - LOGICAL_VIEWPORT.height * scale) / 2;
  return [
    offsetX + logicalPoint[0] * scale,
    offsetY + logicalPoint[1] * scale,
  ];
}

if (coordinateSelfTest) {
  const base = actualPoint([270, 842], { width: 540, height: 960 });
  const tall = actualPoint([270, 842], { width: 886, height: 1920 });
  const wide = actualPoint([270, 480], { width: 1200, height: 960 });
  if (base[0] !== 270 || base[1] !== 842
      || Math.abs(tall[0] - 443) > 1e-9 || Math.abs(tall[1] - 1553.9481481481482) > 1e-9
      || Math.abs(wide[0] - 600) > 1e-9 || Math.abs(wide[1] - 480) > 1e-9) {
    throw new Error(`Aspect-preserving touch coordinate self-test failed: ${JSON.stringify({ base, tall, wide })}`);
  }
  process.stdout.write('bright trailer touch-coordinate self-test: PASS\n');
  process.exit(0);
}

async function dispatchDrag(cdp, fromLogical, toLogical, touchId, viewport, page) {
  const from = actualPoint(fromLogical, viewport);
  const to = actualPoint(toLogical, viewport);
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchStart',
    touchPoints: [{ x: from[0], y: from[1], id: touchId, radiusX: 3, radiusY: 3, force: 1 }],
  });
  for (let step = 1; step <= 4; step += 1) {
    const ratio = step / 4;
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: [{
        x: from[0] + (to[0] - from[0]) * ratio,
        y: from[1] + (to[1] - from[1]) * ratio,
        id: touchId,
        radiusX: 3,
        radiusY: 3,
        force: 1,
      }],
    });
    await page.waitForTimeout(55);
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

function chooseEncoder() {
  const encoders = run(ffmpegBin, ['-hide_banner', '-encoders'], 'FFmpeg encoder discovery').stdout;
  if (/\blibx264\b/.test(encoders) && /\baac\b/.test(encoders)) {
    return {
      container: 'mp4',
      codec: 'h264',
      audioCodec: 'aac',
      extension: '.mp4',
      videoArguments: [
        '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
        '-profile:v', 'high', '-level:v', '4.0', '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart',
      ],
      audioArguments: ['-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-ac', '2'],
      muxArguments: ['-movflags', '+faststart'],
    };
  }
  if (/\blibvpx-vp9\b/.test(encoders) && /\blibopus\b/.test(encoders)) {
    return {
      container: 'webm',
      codec: 'vp9',
      audioCodec: 'opus',
      extension: '.webm',
      videoArguments: ['-c:v', 'libvpx-vp9', '-crf', '24', '-b:v', '0', '-pix_fmt', 'yuv420p'],
      audioArguments: ['-c:a', 'libopus', '-b:a', '192k', '-ar', '48000', '-ac', '2'],
      muxArguments: [],
    };
  }
  throw new Error('No contract-supported H.264/AAC or VP9/Opus FFmpeg encoder pair is available');
}

function boundedDiagnostic(value) {
  return String(value).slice(0, 1024);
}

(async () => {
  fs.mkdirSync(evidenceDirArgument, { recursive: true });
  const evidenceDir = fs.realpathSync(evidenceDirArgument);
  const { contract, contractSha256, audioSourcePath } = loadContract();
  const binding = sourceBinding(targetUrlArgument);
  const rawPath = path.join(evidenceDir, contract.capture.raw_file);
  const manifestPath = path.join(evidenceDir, contract.evidence_manifest);
  const audioEvidencePath = path.join(evidenceDir, contract.audio.source_asset.evidence_file);
  const audioSourceMedia = validateAudioSource(audioSourcePath, contract.audio);
  fs.copyFileSync(audioSourcePath, audioEvidencePath);
  if (sha256File(audioEvidencePath) !== contract.audio.source_asset.sha256) {
    throw new Error('Copied audio evidence differs from the hash-bound repository source');
  }
  const viewport = {
    width: contract.capture.viewport_width,
    height: contract.capture.viewport_height,
  };
  const qaUrl = binding.qa_url;
  const consoleErrors = [];
  const pageErrors = [];
  const pageCrashes = [];
  const criticalRequestFailures = [];
  const chunks = new Map();
  const milestones = [];
  let browser;
  let context;
  let page;
  let recorderStarted = false;
  let rawWritten = false;
  let audioMuxWritten = false;

  const failedManifest = (error) => ({
    schema_version: 2,
    status: 'failed',
    classification: EXPECTED_CLASSIFICATION,
    submission_ready_store_asset: false,
    target_device_evidence: false,
    source_binding: binding,
    contract: {
      id: contract.contract_id,
      file: path.basename(CONTRACT_PATH),
      sha256: contractSha256,
    },
    failure: boundedDiagnostic(error?.stack ?? error),
    capture: {
      actual_gameplay: true,
      generated_or_mocked_frames: false,
      debug_state_injection: false,
      save_manipulation: false,
      browser_audio_captured: false,
      browser_audio_disclosure: contract.capture.browser_audio_disclosure,
      viewport_width: viewport.width,
      viewport_height: viewport.height,
      milestones,
      raw_file: rawWritten ? path.basename(rawPath) : null,
      raw_sha256: rawWritten ? sha256File(rawPath) : null,
    },
    audio: {
      added_to_deliverable: audioMuxWritten,
      source_asset: {
        repository_file: contract.audio.source_asset.repository_file,
        evidence_file: path.basename(audioEvidencePath),
        sha256: contract.audio.source_asset.sha256,
        bytes: contract.audio.source_asset.bytes,
      },
      provenance: contract.audio.provenance,
    },
    diagnostics: { console_errors: consoleErrors, page_errors: pageErrors, page_crashes: pageCrashes, critical_request_failures: criticalRequestFailures },
  });

  async function qaSnapshot() {
    return page.evaluate(() => {
      const snapshot = globalThis.__INFINIDIVE_QA_STATE;
      return snapshot && typeof snapshot === 'object' ? JSON.parse(JSON.stringify(snapshot)) : null;
    });
  }

  async function recorderSeconds() {
    return page.evaluate(() => globalThis.__infinidiveTrailerRecorder?.seconds() ?? null);
  }

  async function markMilestone(key, snapshot) {
    const contractMilestone = contract.semantic_flow.milestones.find((candidate) => candidate.key === key);
    if (!contractMilestone) throw new Error(`Unknown trailer milestone ${key}`);
    if (milestones.some((candidate) => candidate.key === key)) {
      throw new Error(`Trailer milestone ${key} was recorded twice`);
    }
    assertRequiredQa(snapshot, contractMilestone.required_qa, `Trailer milestone ${key}`);
    const captureSeconds = await recorderSeconds();
    if (!finiteNumber(captureSeconds) || captureSeconds < 0) {
      throw new Error(`Trailer milestone ${key} has no recording clock`);
    }
    milestones.push({
      key,
      capture_seconds: Number(captureSeconds.toFixed(6)),
      qa: qaEvidence(snapshot),
    });
  }

  async function waitForState(expectedState, runGeneration, afterRevision, timeoutMs, label) {
    await page.waitForFunction(
      ({ schema, expected, generation, revision }) => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === schema && state.view === 'run' && state.state === expected
          && state.run_generation === generation && Number.isInteger(state.revision)
          && state.revision > revision;
      },
      { schema: QA_SCHEMA, expected: expectedState, generation: runGeneration, revision: afterRevision },
      { timeout: timeoutMs },
    );
    const snapshot = await qaSnapshot();
    if (snapshot.state !== expectedState || snapshot.run_generation !== runGeneration) {
      throw new Error(`${label} did not remain in ${expectedState}: ${JSON.stringify(snapshot)}`);
    }
    return snapshot;
  }

  async function driveUntilState(cdp, expectedState, runGeneration, timeoutMs, label) {
    const patrol = [
      [[270, 790], [120, 760]],
      [[120, 760], [420, 690]],
      [[420, 690], [270, 620]],
      [[270, 620], [420, 780]],
      [[420, 780], [120, 690]],
    ];
    const started = Date.now();
    let patrolIndex = 0;
    while (Date.now() - started < timeoutMs) {
      const snapshot = await qaSnapshot();
      if (!snapshot || snapshot.schema !== QA_SCHEMA || snapshot.view !== 'run') {
        await page.waitForTimeout(100);
        continue;
      }
      if (snapshot.run_generation !== runGeneration) {
        throw new Error(`${label} left the source run: ${JSON.stringify(snapshot)}`);
      }
      if (snapshot.state === expectedState) return snapshot;
      if (TERMINAL_STATES.has(snapshot.state)) {
        throw new Error(`${label} reached ${snapshot.state} before ${expectedState}`);
      }
      if (ACTIVE_INPUT_STATES.has(snapshot.state) && snapshot.controls_active === true) {
        const [from, to] = patrol[patrolIndex % patrol.length];
        patrolIndex += 1;
        await dispatchDrag(cdp, from, to, 100 + patrolIndex, viewport, page);
        if (snapshot.dash_charges >= 1
            && (snapshot.health?.player_ratio <= 0.82 || patrolIndex % 4 === 0)) {
          const dash = actualPoint([72, 874], viewport);
          await page.touchscreen.tap(dash[0], dash[1]);
        }
      }
      await page.waitForTimeout(140);
    }
    throw new Error(`${label} timed out waiting for ${expectedState}: ${JSON.stringify(await qaSnapshot())}`);
  }

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
      viewport,
      hasTouch: true,
      isMobile: true,
      deviceScaleFactor: 1,
    });
    await context.exposeBinding('__infinidiveWriteTrailerChunk', async (_source, sequence, base64) => {
      if (!Number.isInteger(sequence) || sequence < 0 || typeof base64 !== 'string'
          || chunks.has(sequence)) {
        throw new Error(`Invalid MediaRecorder chunk ${JSON.stringify(sequence)}`);
      }
      chunks.set(sequence, Buffer.from(base64, 'base64'));
    });
    page = await context.newPage();
    page.on('console', (message) => {
      if (message.type() === 'error' && consoleErrors.length < MAX_DIAGNOSTICS) {
        consoleErrors.push(boundedDiagnostic(message.text()));
      }
    });
    page.on('pageerror', (error) => {
      if (pageErrors.length < MAX_DIAGNOSTICS) pageErrors.push(boundedDiagnostic(error));
    });
    page.on('crash', () => {
      if (pageCrashes.length < MAX_DIAGNOSTICS) pageCrashes.push('page crashed');
    });
    page.on('requestfailed', (request) => {
      if (criticalRequestFailures.length >= MAX_DIAGNOSTICS) return;
      let pathname = '';
      try { pathname = new URL(request.url()).pathname; } catch (_) { return; }
      if (/\.(?:js|mjs|wasm|pck)$/i.test(pathname)) {
        criticalRequestFailures.push({
          url: sanitizedUrl(request.url()),
          error: boundedDiagnostic(request.failure()?.errorText ?? 'unknown request failure'),
        });
      }
    });

    const response = await page.goto(qaUrl, { waitUntil: 'domcontentloaded', timeout: 30_000 });
    if (!response || !response.ok()) {
      throw new Error(`Trailer target returned HTTP ${response?.status() ?? 'no response'}`);
    }
    await page.waitForFunction(
      ({ schema, width, height }) => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        const canvas = document.getElementById('canvas');
        const status = document.getElementById('status');
        return state?.schema === schema && state.view === 'nest'
          && canvas?.width === width && canvas?.height === height
          && status?.classList.contains('hidden') === true;
      },
      { schema: QA_SCHEMA, width: viewport.width, height: viewport.height },
      { timeout: 90_000 },
    );
    const nestSnapshot = await qaSnapshot();
    if (!nestSnapshot || nestSnapshot.view !== 'nest' || nestSnapshot.run_generation !== 0
        || nestSnapshot.persistence?.save_source !== 'default') {
      throw new Error(`Trailer capture did not begin from a fresh Nest: ${JSON.stringify(nestSnapshot)}`);
    }

    const recorderInfo = await page.evaluate(async ({ width, height }) => {
      const canvas = document.getElementById('canvas');
      if (!canvas || canvas.width !== width || canvas.height !== height
          || typeof canvas.captureStream !== 'function' || typeof MediaRecorder !== 'function') {
        throw new Error('The live Godot canvas does not support truthful MediaRecorder capture');
      }
      const mimeTypes = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'];
      const mimeType = mimeTypes.find((candidate) => MediaRecorder.isTypeSupported(candidate));
      if (!mimeType) throw new Error('No WebM MediaRecorder codec is available');
      const stream = canvas.captureStream(30);
      const recorder = new MediaRecorder(stream, { mimeType, videoBitsPerSecond: 12_000_000 });
      const pending = [];
      let sequence = 0;
      let startedAt = null;
      let stopResolve;
      let stopReject;
      const stopped = new Promise((resolve, reject) => {
        stopResolve = resolve;
        stopReject = reject;
      });
      const toBase64 = (blob) => new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onerror = () => reject(reader.error ?? new Error('MediaRecorder FileReader failed'));
        reader.onload = () => resolve(String(reader.result).split(',', 2)[1]);
        reader.readAsDataURL(blob);
      });
      recorder.ondataavailable = (event) => {
        if (!event.data || event.data.size === 0) return;
        const chunkSequence = sequence;
        sequence += 1;
        const transfer = toBase64(event.data).then(
          (base64) => globalThis.__infinidiveWriteTrailerChunk(chunkSequence, base64),
        );
        pending.push(transfer);
      };
      recorder.onerror = (event) => stopReject(event.error ?? new Error('MediaRecorder failed'));
      recorder.onstop = () => Promise.all(pending).then(
        () => stopResolve({ chunk_count: sequence, elapsed_seconds: (performance.now() - startedAt) / 1000 }),
        stopReject,
      );
      const started = new Promise((resolve, reject) => {
        recorder.onstart = () => {
          startedAt = performance.now();
          resolve();
        };
        setTimeout(() => reject(new Error('MediaRecorder did not start')), 5_000);
      });
      recorder.start(750);
      await started;
      globalThis.__infinidiveTrailerRecorder = {
        seconds: () => (performance.now() - startedAt) / 1000,
        stop: async () => {
          if (recorder.state !== 'inactive') recorder.stop();
          const result = await stopped;
          for (const track of stream.getTracks()) track.stop();
          return result;
        },
      };
      return { mime_type: mimeType, frame_rate: 30, video_bits_per_second: recorder.videoBitsPerSecond };
    }, viewport);
    recorderStarted = true;

    const start = actualPoint([270, 842], viewport);
    await page.touchscreen.tap(start[0], start[1]);
    await page.waitForFunction(
      ({ schema, revision, generation }) => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === schema && state.view === 'run' && state.state === 'EXTERIOR'
          && state.controls_active === true && state.run_generation === generation + 1
          && state.revision > revision && state.movement_observed === false;
      },
      { schema: QA_SCHEMA, revision: nestSnapshot.revision, generation: nestSnapshot.run_generation },
      { timeout: 15_000 },
    );
    const runStart = await qaSnapshot();
    await markMilestone('run_start_unarmed', runStart);
    await page.waitForTimeout(3_100);

    const cdp = await context.newCDPSession(page);
    await dispatchDrag(cdp, [410, 700], [345, 625], 1, viewport, page);
    await page.waitForFunction(
      ({ schema, generation, revision }) => {
        const state = globalThis.__INFINIDIVE_QA_STATE;
        return state?.schema === schema && state.view === 'run' && state.state === 'EXTERIOR'
          && state.run_generation === generation && state.revision > revision
          && state.movement_observed === true;
      },
      { schema: QA_SCHEMA, generation: runStart.run_generation, revision: runStart.revision },
      { timeout: 5_000 },
    );
    const exteriorCombat = await qaSnapshot();
    await markMilestone('exterior_combat', exteriorCombat);

    const breachOpen = await driveUntilState(
      cdp, 'BREACH_OPEN', runStart.run_generation, 90_000, 'Breach opening',
    );
    await markMilestone('breach_open', breachOpen);
    await page.waitForTimeout(350);

    const dive = actualPoint([476, 888], viewport);
    await page.touchscreen.tap(dive[0], dive[1]);
    const organSelect = await waitForState(
      'ORGAN_SELECT', runStart.run_generation, breachOpen.revision, 5_000, 'Organ selection',
    );
    await markMilestone('organ_select', organSelect);
    await page.waitForTimeout(500);

    const hunterEye = actualPoint([270, 421], viewport);
    await page.touchscreen.tap(hunterEye[0], hunterEye[1]);
    const divingIn = await waitForState(
      'DIVING_IN', runStart.run_generation, organSelect.revision, 5_000, 'Dive in',
    );
    await markMilestone('diving_in', divingIn);

    const internalRooms = await driveUntilState(
      cdp, 'INTERNAL_ROOMS', runStart.run_generation, 10_000, 'Internal rooms',
    );
    await markMilestone('internal_rooms', internalRooms);
    await page.waitForTimeout(2_100);

    const organChamber = await driveUntilState(
      cdp, 'ORGAN_CHAMBER', runStart.run_generation, 120_000, 'Organ chamber',
    );
    await markMilestone('organ_chamber', organChamber);

    const mutationChoice = await driveUntilState(
      cdp, 'MUTATION_CHOICE', runStart.run_generation, 120_000, 'Organ destruction',
    );
    await markMilestone('mutation_choice', mutationChoice);
    await page.waitForTimeout(450);

    const mutation = actualPoint([270, 360], viewport);
    await page.touchscreen.tap(mutation[0], mutation[1]);
    const divingOut = await waitForState(
      'DIVING_OUT', runStart.run_generation, mutationChoice.revision, 5_000, 'Dive out',
    );
    await markMilestone('diving_out', divingOut);
    await page.waitForTimeout(400);

    const changedExterior = await waitForState(
      'EXTERIOR', runStart.run_generation, divingOut.revision, 8_000, 'Changed exterior',
    );
    await markMilestone('changed_exterior', changedExterior);
    await page.waitForTimeout(3_200);

    const stopResult = await page.evaluate(() => globalThis.__infinidiveTrailerRecorder.stop());
    recorderStarted = false;
    const orderedChunks = [...chunks.entries()].sort((left, right) => left[0] - right[0]);
    if (orderedChunks.length !== stopResult.chunk_count
        || orderedChunks.some(([sequence], index) => sequence !== index)) {
      throw new Error(`MediaRecorder chunks are incomplete: ${JSON.stringify({ ordered: orderedChunks.length, stopResult })}`);
    }
    const rawBytes = Buffer.concat(orderedChunks.map((entry) => entry[1]));
    if (rawBytes.length < 100_000) throw new Error(`Raw gameplay recording is implausibly small: ${rawBytes.length}`);
    const normalizedRawPath = path.join(evidenceDir, '.infinidive-bright-trailer-normalized.webm');
    fs.writeFileSync(rawPath, rawBytes);
    rawWritten = true;
    // MediaRecorder WebM is a truthful continuous canvas recording, but some
    // Chromium versions omit a seekable container duration. A video-copy
    // remux preserves every encoded gameplay frame while making the evidence
    // independently trim/seek/FFprobe-safe.
    run(
      ffmpegBin,
      [
        '-hide_banner', '-loglevel', 'error', '-y', '-fflags', '+genpts',
        '-i', rawPath, '-map', '0:v:0', '-c:v', 'copy', '-an', normalizedRawPath,
      ],
      'MediaRecorder WebM normalization',
    );
    fs.renameSync(normalizedRawPath, rawPath);

    if (consoleErrors.length || pageErrors.length || pageCrashes.length || criticalRequestFailures.length) {
      throw new Error(`Runtime diagnostics failed: ${JSON.stringify({ consoleErrors, pageErrors, pageCrashes, criticalRequestFailures })}`);
    }
    const expectedMilestoneKeys = contract.semantic_flow.milestones.map((milestone) => milestone.key);
    if (JSON.stringify(milestones.map((milestone) => milestone.key)) !== JSON.stringify(expectedMilestoneKeys)) {
      throw new Error(`Trailer milestones are incomplete: ${JSON.stringify(milestones.map((value) => value.key))}`);
    }
    for (let index = 1; index < milestones.length; index += 1) {
      if (milestones[index].capture_seconds <= milestones[index - 1].capture_seconds
          || milestones[index].qa.revision <= milestones[index - 1].qa.revision
          || milestones[index].qa.run_generation !== milestones[0].qa.run_generation) {
        throw new Error(`Trailer milestone timeline is not one monotonic run: ${JSON.stringify(milestones[index])}`);
      }
    }
    const coreStates = milestones
      .filter((milestone) => milestone.key !== 'exterior_combat')
      .map((milestone) => milestone.qa.state);
    if (JSON.stringify(coreStates) !== JSON.stringify(contract.semantic_flow.expected_states)) {
      throw new Error(`Trailer semantic path differs from contract: ${JSON.stringify(coreStates)}`);
    }

    const rawProbe = ffprobe(rawPath);
    const rawVideo = videoStream(rawProbe);
    const rawDuration = Number(rawProbe.format?.duration);
    if (!rawVideo || rawVideo.width !== viewport.width || rawVideo.height !== viewport.height
        || audioStreams(rawProbe).length !== 0 || !finiteNumber(rawDuration)) {
      throw new Error(`Raw trailer dimensions/duration are invalid: ${JSON.stringify(rawProbe)}`);
    }
    const anchorTimes = Object.fromEntries(
      milestones.map((milestone) => [milestone.key, milestone.capture_seconds]),
    );
    const segments = contract.editing.ordered_segments.map((segment) => {
      const startSeconds = anchorTimes[segment.start_anchor] + segment.start_offset_seconds;
      const endSeconds = anchorTimes[segment.end_anchor] + segment.end_offset_seconds;
      if (startSeconds < 0 || endSeconds <= startSeconds || endSeconds > rawDuration + 0.075) {
        throw new Error(`Trailer edit segment falls outside raw capture: ${JSON.stringify({ segment, startSeconds, endSeconds, rawDuration })}`);
      }
      return {
        key: segment.key,
        start_anchor: segment.start_anchor,
        start_offset_seconds: segment.start_offset_seconds,
        end_anchor: segment.end_anchor,
        end_offset_seconds: segment.end_offset_seconds,
        start_seconds: Number(startSeconds.toFixed(6)),
        end_seconds: Number(endSeconds.toFixed(6)),
        duration_seconds: Number((endSeconds - startSeconds).toFixed(6)),
      };
    });
    const intendedDuration = segments.reduce((total, segment) => total + segment.duration_seconds, 0);
    if (intendedDuration < contract.deliverable.minimum_duration_seconds
        || intendedDuration > contract.deliverable.maximum_duration_seconds) {
      throw new Error(`Contract edit duration is ${intendedDuration}s, outside 15–30 seconds`);
    }

    const encoder = chooseEncoder();
    const deliverableFile = encoder.container === 'mp4'
      ? contract.deliverable.preferred_file
      : contract.deliverable.preferred_file.replace(/\.mp4$/i, encoder.extension);
    assertSafeBasename(deliverableFile, encoder.extension, 'Trailer deliverable');
    const deliverablePath = path.join(evidenceDir, deliverableFile);
    const videoOnlyPath = path.join(evidenceDir, `.infinidive-bright-trailer-video-only${encoder.extension}`);
    const filterParts = [];
    const concatInputs = [];
    segments.forEach((segment, index) => {
      filterParts.push(
        `[0:v]trim=start=${segment.start_seconds.toFixed(6)}:end=${segment.end_seconds.toFixed(6)},setpts=PTS-STARTPTS[s${index}]`,
      );
      concatInputs.push(`[s${index}]`);
    });
    filterParts.push(
      `${concatInputs.join('')}concat=n=${segments.length}:v=1:a=0,fps=${contract.deliverable.maximum_frame_rate},format=yuv420p[v]`,
    );
    run(
      ffmpegBin,
      [
        '-hide_banner', '-loglevel', 'error', '-y', '-i', rawPath,
        '-filter_complex', filterParts.join(';'), '-map', '[v]', '-an',
        ...encoder.videoArguments, '-fps_mode', 'cfr', videoOnlyPath,
      ],
      'Bright trailer hard-cut video edit',
    );
    const videoOnlyProbe = ffprobe(videoOnlyPath);
    const videoOnlyStream = videoStream(videoOnlyProbe);
    const videoOnlyDuration = Number(videoOnlyProbe.format?.duration);
    if (!videoOnlyStream || audioStreams(videoOnlyProbe).length !== 0
        || videoOnlyStream.codec_name !== encoder.codec
        || videoOnlyStream.width !== viewport.width || videoOnlyStream.height !== viewport.height
        || videoOnlyStream.pix_fmt !== 'yuv420p' || !finiteNumber(videoOnlyDuration)
        || videoOnlyDuration < contract.deliverable.minimum_duration_seconds
        || videoOnlyDuration > contract.deliverable.maximum_duration_seconds
        || videoOnlyDuration > audioSourceMedia.duration + 0.001) {
      throw new Error(`Video-only trailer edit does not meet the media contract: ${JSON.stringify(videoOnlyProbe)}`);
    }
    const videoPacketSha256BeforeAudioMux = videoPacketSha256(videoOnlyPath);
    run(
      ffmpegBin,
      [
        '-hide_banner', '-loglevel', 'error', '-y',
        '-i', videoOnlyPath, '-i', audioEvidencePath,
        '-map', '0:v:0', '-map', '1:a:0',
        '-filter:a', `atrim=start=0:end=${videoOnlyDuration.toFixed(6)},asetpts=PTS-STARTPTS`,
        '-c:v', 'copy', ...encoder.audioArguments, ...encoder.muxArguments,
        '-shortest', deliverablePath,
      ],
      'Bright trailer original-game audio mux',
    );
    audioMuxWritten = true;
    run(ffmpegBin, ['-hide_banner', '-v', 'error', '-i', deliverablePath, '-f', 'null', '-'], 'Trailer decode');
    const deliverableProbe = ffprobe(deliverablePath);
    const deliveredVideo = videoStream(deliverableProbe);
    const deliveredAudioStreams = audioStreams(deliverableProbe);
    const deliveredAudio = deliveredAudioStreams[0];
    const deliveredDuration = Number(deliverableProbe.format?.duration);
    if (!deliveredVideo || deliveredVideo.codec_name !== encoder.codec
        || deliveredVideo.width !== viewport.width || deliveredVideo.height !== viewport.height
        || deliveredVideo.pix_fmt !== 'yuv420p'
        || deliveredAudioStreams.length !== contract.audio.track_count
        || deliveredAudio?.codec_name !== encoder.audioCodec
        || Number(deliveredAudio?.sample_rate) !== contract.audio.mux.encoded_sample_rate
        || deliveredAudio?.channels !== contract.audio.mux.encoded_channels
        || !finiteNumber(deliveredDuration)
        || deliveredDuration < contract.deliverable.minimum_duration_seconds
        || deliveredDuration > contract.deliverable.maximum_duration_seconds
        || Number(deliverableProbe.format?.size) > contract.deliverable.maximum_bytes) {
      throw new Error(`Edited trailer does not meet the media contract: ${JSON.stringify(deliverableProbe)}`);
    }
    const videoPacketSha256AfterAudioMux = videoPacketSha256(deliverablePath);
    if (videoPacketSha256AfterAudioMux !== videoPacketSha256BeforeAudioMux) {
      throw new Error('Audio mux changed the encoded live-gameplay video packet stream');
    }
    const deliveredAudioLevels = audioLevels(deliverablePath, 'Bright trailer encoded-audio level analysis');
    assertAudioLevels(deliveredAudioLevels, contract.audio.validation, 'Bright trailer encoded audio');
    fs.unlinkSync(videoOnlyPath);

    const manifest = {
      schema_version: 2,
      status: 'captured_pending_independent_validation',
      classification: EXPECTED_CLASSIFICATION,
      submission_ready_store_asset: false,
      target_device_evidence: false,
      source_binding: binding,
      contract: {
        id: contract.contract_id,
        file: path.basename(CONTRACT_PATH),
        sha256: contractSha256,
      },
      capture: {
        surface: 'live_godot_web_canvas_mediarecorder_in_headless_chrome',
        qa_mode: true,
        actual_gameplay: true,
        generated_or_mocked_frames: false,
        debug_state_injection: false,
        save_manipulation: false,
        browser_audio_captured: false,
        browser_audio_disclosure: contract.capture.browser_audio_disclosure,
        viewport_width: viewport.width,
        viewport_height: viewport.height,
        device_scale_factor: 1,
        has_touch: true,
        is_mobile: true,
        recorder: recorderInfo,
        elapsed_seconds: stopResult.elapsed_seconds,
        raw_file: path.basename(rawPath),
        raw_sha256: sha256File(rawPath),
        raw_bytes: fs.statSync(rawPath).size,
        raw_audio_tracks: 0,
        raw_probe: rawProbe,
        milestones,
        observed_states: coreStates,
      },
      editing: {
        kind: contract.editing.kind,
        one_continuous_source: true,
        speed_multiplier: 1.0,
        hard_cuts_only: true,
        overlays: false,
        drawn_text: false,
        fabricated_ui: false,
        compositing: false,
        cropping: false,
        scaling: false,
        generated_gameplay_frames: false,
        segments,
        intended_duration_seconds: Number(intendedDuration.toFixed(6)),
        video_integrity: {
          mux_video_mode: contract.audio.mux.video_mode,
          packet_sha256_before_audio_mux: videoPacketSha256BeforeAudioMux,
          packet_sha256_after_audio_mux: videoPacketSha256AfterAudioMux,
          identical_before_and_after_audio_mux: true,
        },
      },
      audio: {
        track_count: contract.audio.track_count,
        source_asset: {
          repository_file: contract.audio.source_asset.repository_file,
          evidence_file: path.basename(audioEvidencePath),
          sha256: contract.audio.source_asset.sha256,
          bytes: fs.statSync(audioEvidencePath).size,
          codec: contract.audio.source_asset.codec,
          sample_rate: contract.audio.source_asset.sample_rate,
          channels: contract.audio.source_asset.channels,
          duration_seconds: audioSourceMedia.duration,
          mean_volume_dbfs: audioSourceMedia.meanVolumeDbfs,
          peak_volume_dbfs: audioSourceMedia.peakVolumeDbfs,
          probe: audioSourceMedia.probe,
        },
        provenance: contract.audio.provenance,
        mux: {
          timing: contract.audio.mux.timing,
          video_mode: contract.audio.mux.video_mode,
          encoded_codec: encoder.audioCodec,
          encoded_sample_rate: Number(deliveredAudio.sample_rate),
          encoded_channels: deliveredAudio.channels,
          source_trim_end_seconds: videoOnlyDuration,
        },
      },
      deliverable: {
        file: deliverableFile,
        sha256: sha256File(deliverablePath),
        bytes: fs.statSync(deliverablePath).size,
        container: encoder.container,
        video_codec: encoder.codec,
        audio_codec: encoder.audioCodec,
        audio_tracks: contract.audio.track_count,
        audio_levels: {
          mean_volume_dbfs: deliveredAudioLevels.meanVolumeDbfs,
          peak_volume_dbfs: deliveredAudioLevels.peakVolumeDbfs,
        },
        probe: deliverableProbe,
      },
      diagnostics: {
        console_errors: consoleErrors,
        page_errors: pageErrors,
        page_crashes: pageCrashes,
        critical_request_failures: criticalRequestFailures,
      },
      limitations: [
        'Browser gameplay capture is not native-iOS or physical-device evidence.',
        'The project-original procedural music bed was added offline; it is not live-captured or event-synchronous gameplay audio.',
        'Independent media validation and human audiovisual review are still required.',
        'This artifact does not prove App Store Connect processing, acceptance, or approval.',
      ],
    };
    fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
    process.stdout.write(`${JSON.stringify({
      status: 'captured_pending_independent_validation',
      manifest: path.basename(manifestPath),
      raw_file: path.basename(rawPath),
      deliverable: deliverableFile,
      duration_seconds: deliveredDuration,
      source_commit: binding.commit,
    })}\n`);
  } catch (error) {
    try {
      if (recorderStarted && page && !page.isClosed()) {
        await page.evaluate(() => globalThis.__infinidiveTrailerRecorder?.stop());
        recorderStarted = false;
        const orderedChunks = [...chunks.entries()].sort((left, right) => left[0] - right[0]);
        if (orderedChunks.length > 0) {
          fs.writeFileSync(rawPath, Buffer.concat(orderedChunks.map((entry) => entry[1])));
          rawWritten = true;
        }
      }
    } catch (_) {
      // The original capture failure remains authoritative.
    }
    fs.writeFileSync(manifestPath, `${JSON.stringify(failedManifest(error), null, 2)}\n`);
    throw error;
  } finally {
    if (context) await context.close().catch(() => {});
    if (browser) await browser.close().catch(() => {});
  }
})().catch((error) => {
  process.stderr.write(`${error.stack ?? error}\n`);
  process.exitCode = 1;
});
