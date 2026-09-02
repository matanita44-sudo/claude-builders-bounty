# INFINIDIVE signed iOS release runbook

This runbook covers `.github/workflows/infinidive-ios-release.yml`. It is a
manual, protected path for producing and validating a signed App Store archive
and IPA. Automated App Store Connect delivery is currently fail-closed pending
a protected Xcode 26 run that captures and reviews Apple's actual `altool` JSON
schemas; keep the upload input false until that gate is deliberately updated.

The workflow does not submit a build for review, select a public-release date,
or release the app. A successful upload command proves delivery acceptance
only. App Store Connect processing, TestFlight installation, physical-device
QA, App Review, and public release remain separate gates.

No signed archive, IPA, TestFlight build, or App Store upload has been produced
merely because this workflow and validator exist. Record those claims only
after the corresponding protected run and external Apple state are inspected.

## Frozen source contract

For the current release line, the workflow accepts only source that agrees with
all of these values:

| Coordinate | Current source value |
|---|---|
| Bundle identifier | `com.matan.infinidive` |
| Marketing version | `0.1.0` |
| Build number | `1` |
| Minimum iOS | `15.0` |
| Device family | iPhone only |
| Orientation | portrait only |
| Apple Team ID in source | blank |

The source Team ID must remain blank in
`infinidive-game/export_presets.cfg`. Never commit a Team ID, certificate,
private key, P12 password, provisioning profile, or App Store Connect key.

Before using a later version/build, update and review all source-bound version
locations in the same commit, including:

- `infinidive-game/export_presets.cfg`
- `infinidive-game/project.godot`
- the reviewed constants in
  `.github/scripts/validate_ios_project_metadata.py`
- store metadata/release notes that state a version or build

Changing only a workflow input is intentionally insufficient. App Store build
numbers are monotonic and cannot be reused after Apple accepts that
bundle/version/build.

## One-time repository and Apple setup

### Protected control branch, default-branch registration, and source tags

Create and protect a branch named exactly `infinidive-production`. Require pull
request review, the complete `INFINIDIVE CI and Web Pages` check, and no routine
administrator bypass or direct pushes. Only this branch may execute the signed
release workflow; its dispatch commit supplies every script and release control.

GitHub delivers `workflow_dispatch` only for workflows present on the default
branch. This repository's default branch is currently `main`, so the reviewed
`.github/workflows/infinidive-ios-release.yml` must also be merged byte-for-byte
to `main` before this path is runnable. The workflow compares that registration
copy with the protected `infinidive-production` copy and fails closed on drift.
Until this merge (or an owner-approved default-branch change/dedicated release
repository) is complete, the workflow is intentionally **ready but blocked**.

Protect `ios-v*` source tags with a separate repository ruleset. Restrict tag
creation to release owners and block updates/deletion. A tag must point to a
commit on `infinidive-production` with a successful exact-SHA run of
`.github/workflows/infinidive-ci.yml`. The trusted control commit may be newer,
but the tag commit must be its Git ancestor.

### Protected release environment

Create a GitHub environment named exactly `app-store-production` and configure:

1. Required reviewers who inspect the control commit, exact tag/source SHA, and
   requested coordinates.
2. Prevent self-approval where the repository plan supports it.
3. Deployment branch restrictions permitting only `infinidive-production`.
4. No tag-only, untrusted-branch, or pull-request deployment rules.
5. The protected environment secrets listed below.

The workflow rejects every dispatch ref except `infinidive-production`, resolves
the immutable tag SHA independently in both jobs, proves its ancestry against
the trusted control commit, and requires a successful exact-SHA production CI
run before importing Apple secrets. These checks do not replace the rulesets.

The signing job must stay on the GitHub-hosted `macos-26-intel` runner. A
self-hosted runner needs separately reviewed isolation and cancellation
cleanup and is outside this runbook.

### Required protected secrets

Configure these secrets on `app-store-production`, not as repository files:

| Secret | Exact content | Required when |
|---|---|---|
| `APPLE_TEAM_ID` | The ten-character uppercase Apple Developer Team ID | Every signed run |
| `APPLE_DISTRIBUTION_CERTIFICATE_BASE64` | Base64 of one P12 containing the Apple Distribution certificate and matching private key | Every signed run |
| `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password protecting that P12; use a non-empty password | Every signed run |
| `APPLE_APP_STORE_PROVISIONING_PROFILE_BASE64` | Base64 of the explicit App Store `.mobileprovision` for `com.matan.infinidive` | Every signed run |
| `APP_STORE_CONNECT_API_KEY_ID` | Ten-character App Store Connect API key ID | Future upload calibration only; not needed while upload is blocked |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect issuer UUID | Future upload calibration only; not needed while upload is blocked |
| `APP_STORE_CONNECT_API_PRIVATE_KEY_BASE64` | Base64 of the complete `AuthKey_*.p8` private-key file | Future upload calibration only; not needed while upload is blocked |

The distribution certificate and provisioning profile must be unexpired and
belong to the same Team ID. The profile must authorize the exact bundle ID and
the imported certificate, list an iOS-compatible platform, have
`get-task-allow=false` and `beta-reports-active=true`, contain no device list or
enterprise distribution flag, and enable no unreviewed capability.

This workflow supports App Store Connect **team API keys** with an issuer UUID;
those keys are team-wide and cannot be scoped to one app. Use the least role
capable of uploading builds and a dedicated key with a short, recorded rotation
lifecycle. Individual API keys use a different JWT subject flow and are not
accepted by this workflow. Never grant Admin only for this workflow.

To prepare base64 locally without printing secret material to the terminal or
placing it in a command-line argument:

```bash
umask 077
openssl base64 -A -in /absolute/secure/path/distribution.p12 \
  -out /absolute/secure/path/distribution.p12.base64
openssl base64 -A -in /absolute/secure/path/app-store.mobileprovision \
  -out /absolute/secure/path/app-store.mobileprovision.base64
openssl base64 -A -in /absolute/secure/path/AuthKey_KEYID.p8 \
  -out /absolute/secure/path/AuthKey_KEYID.p8.base64
```

Paste the file contents into the matching environment-secret fields through
the GitHub UI or another approved secret-management path, then remove the
temporary base64 files. Do not pass secret values as `gh secret set --body`
arguments or commit the encoded files; base64 is not encryption.

### Apple account records

Before the first upload, an authorized owner must confirm all of the following:

- active Apple Developer Program membership and accepted agreements;
- an explicit Bundle ID record for `com.matan.infinidive` on the selected team;
- a matching App Store provisioning profile and Apple Distribution identity;
- an App Store Connect app record using that Bundle ID and an unused SKU;
- that app record's numeric Apple ID from **App Information**;
- API-key access to that app, if automated upload will be used;
- current tax, banking, contracts, roles, and two-factor/account requirements.

These are account/owner blockers; source code cannot create or truthfully
attest to them.

## Supply-chain pins

The release workflow intentionally pins every reusable action to a full commit:

| Action | Reviewed version | Commit |
|---|---|---|
| `actions/checkout` | `v7.0.1` | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/upload-artifact` | `v7.0.1` | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| `actions/download-artifact` | `v8.0.1` | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` |

Update a pin only in a reviewed source commit after checking the upstream
release and exact digest. These versions use the Node 24 action runtime and
require Actions Runner `2.327.1` or newer; GitHub-hosted runners satisfy that
requirement. Do not replace full SHAs with moving version tags.

## Pre-tag validation

Run these secretless checks from a clean candidate checkout:

```bash
PYTHONDONTWRITEBYTECODE=1 \
  python3 .github/scripts/validate_ios_release_archive.py --self-test

PYTHONDONTWRITEBYTECODE=1 \
  python3 .github/scripts/validate_ios_release_archive.py \
    --source-preset infinidive-game/export_presets.cfg \
    --project infinidive-game/project.godot \
    --bundle-id com.matan.infinidive \
    --marketing-version 0.1.0 \
    --build-number 1
```

The main secretless CI must run both commands whenever the release workflow,
signed validator, export preset, project version, or metadata validator changes.
Its workflow path must include the release workflow as a trigger. The signed
release path additionally queries the Actions API and rejects a tag SHA without
a successful completed `INFINIDIVE CI and Web Pages` run on
`infinidive-production`. A local parse is not signed-build evidence.

Complete the ordinary release checklist and freeze a clean commit before
tagging. The exact tag format is:

```text
ios-v<marketing-version>-build.<build-number>
```

For the current coordinates it is:

```text
ios-v0.1.0-build.1
```

Create and push the protected tag only after the candidate commit is final.
Do not move or recreate the tag after a run. A changed source tree, reused build
number, or failed candidate requires a new commit and, when the build number
changes, a new matching tag.

## Manual dispatch inputs

In GitHub Actions, select **INFINIDIVE signed iOS release**, choose **Run
workflow**, select the protected `infinidive-production` branch in the ref
dropdown, and enter the source tag separately:

| Input | Current value | Contract |
|---|---|---|
| `release_tag` | `ios-v0.1.0-build.1` | Protected immutable source tag; must match version/build and be an ancestor of the trusted control commit |
| `bundle_identifier` | `com.matan.infinidive` | Must match source, profile, Apple Bundle ID, and App Store Connect app |
| `marketing_version` | `0.1.0` | Must match source and tag; two or three integer components |
| `build_number` | `1` | Must match source/tag and be unused in App Store Connect; one to three integer components |
| `apple_app_id` | blank | Must remain blank while automated upload is blocked |
| `upload_to_app_store_connect` | `false` | `true` is intentionally rejected before secrets until protected Xcode 26 JSON-schema calibration is reviewed |

The workflow is `workflow_dispatch` only. It cannot run from `push`, pull
requests, schedules, `workflow_run`, or another reusable workflow.

## What the protected run does

The first, secretless Ubuntu job:

1. Loads controls only from the protected dispatch commit, treats the tag as
   data, and requires a byte-identical workflow registration on default `main`.
2. Requires the exact `ios-v<version>-build.<build>` tag/SHA, trusted-control
   ancestry, and successful exact-SHA production CI.
3. Validates bundle/version/build, privacy settings, and the blank source Team ID.
4. Runs the signed-validator and existing iOS validator self-tests.
5. Installs the repository's hash-verified Godot editor/template inputs.
6. Uses an obvious fake Team ID only in an ephemeral project copy so Godot can
   regenerate the Xcode scaffold.
7. Sanitizes and validates Info.plist, privacy, launch screen, icons, target,
   scheme, empty entitlements, and source/run binding.
8. Removes the fake Team ID and applies an exact reviewed Xcode build-settings
   manifest; it rejects scripts, packages, per-file compiler settings, unsafe
   Copy Files phases, and executable scheme actions before secrets are exposed.
9. Uploads the unsigned, source-bound scaffold for one day.

After protected-environment approval, the macOS job:

1. Selects the newest valid source/run-bound scaffold at or before the current
   attempt and requires Xcode 26.x plus the iOS 26.x SDK.
2. Creates a temporary keychain with a random masked password, imports exactly
   one distribution identity, decodes the profile, and installs it under the
   Xcode provisioning-profile directory by validated UUID without overwriting
   an existing file.
3. Proves Team/bundle/profile/certificate equality, expiry, App Store
   distribution, debugger prohibition, and entitlement allowlist; the embedded
   profile UUID/bytes and signing leaf certificate must match preflight exactly.
4. Archives with manual signing and no portal-mutation flag.
5. Validates archive metadata, strict code signatures, entitlements, embedded
   profile, arm64 executable/libraries, matching dSYM, privacy manifest,
   compiled AppIcon catalog, framework inventory, and a Godot PCK whose SHA-256
   must equal the exact source-bound scaffold PCK.
6. Exports one signed IPA and validates its exact payload and equality with the
   archive for source data, Info.plist, privacy, icons, entitlements, profile,
   and framework inventory.
7. Rejects automated upload fail-closed. The dormant implementation uses current
   `altool --validate-app`/`--upload-package` coordinates and bounded parsing,
   but it must not be enabled until real Xcode 26 success/error JSON fixtures are
   captured in a protected run and converted into exact schemas/negative tests.
8. Writes bounded evidence, removes the profile and all signing/API material,
   restores the prior keychain search list, and deletes the archive and IPA.

“Archive only” means no App Store Connect upload. The workflow still exports a
local IPA so archive-to-IPA validation can run; both signed outputs are deleted
after checks. The public repository's Actions artifacts intentionally do not
retain the signed IPA or `.xcarchive`.

## Evidence and interpretation

The `infinidive-ios-release-evidence-<attempt>` artifact is retained for 30
days. On a fully successful run it contains:

- `signing-preflight.json`: scrubbed profile/certificate expiry plus certificate
  SHA-256, without Team ID, certificate/profile payload, name, or UUID;
- `archive-validation.json`: signed archive validation bound to source/run;
- `ios-release-evidence.json`: archive/IPA validation and IPA SHA-256;
- `asc-validation.json`: future bounded Apple package-validation result; absent
  while automated upload remains blocked;
- `upload-status.json`: `not-requested` or
  `uploaded-awaiting-app-store-connect-processing`;
- `source-binding.txt` and `toolchain.txt`;
- `SHA256SUMS` for the IPA by logical name and retained evidence files;
- `README.md` explaining the evidence boundary.

A failed run may contain only the subset created before failure. The IPA line in
`SHA256SUMS` is a digest record, not a retained IPA. Never infer an archive,
upload, processing success, review approval, or release from the presence of an
Actions run alone; inspect the validator result and, for uploads, App Store
Connect.

Evidence is copied after build execution into a fresh public directory using a
fixed filename, size, non-symlink, JSON-schema, and status allowlist. The private
working evidence directory is deleted before only that bounded directory is
uploaded; unexpected entries fail the evidence step.

The cleanup step runs with `always()` and deletes only fixed paths under the
GitHub-hosted runner's temporary directory plus the exact UUID-named profile it
installed. If a run is forcibly cancelled before cleanup executes, rely on the
ephemeral GitHub-hosted runner destruction, then rotate credentials if runner
isolation is ever in doubt.

## After a future owner-enabled upload

1. Check App Store Connect for the exact bundle/version/build and record whether
   processing is pending, failed, or complete.
2. If `altool` times out or returns an ambiguous result, check App Store Connect
   before retrying. Never blindly upload the same build again.
3. Install the processed build through TestFlight and complete physical-device
   QA on supported small and large iPhones, including touch, safe areas,
   background/force-close persistence, audio, performance, and accessibility.
4. Reconcile the final binary/SDK inventory with App Privacy and export
   compliance. `ITSAppUsesNonExemptEncryption=false` is a binary assertion, not
   permission to guess Apple's questionnaire answers.
5. Capture final screenshots/App Preview from the exact reviewed release
   candidate; do not use superseded pre-pivot media.
6. Complete and owner-approve store name/rights, descriptions, keywords,
   screenshots, age rating, privacy answers, encryption answers, review contact,
   review notes, territories, copyright, legal notices, and release method.
7. Submit for review manually. After approval, release manually only after one
   final owner check of the selected version/build and availability.

## Failure and credential rotation

- A secretless scaffold failure exposes no Apple credentials. Fix source in a
  new commit; do not move a protected tag.
- A signing preflight failure usually means the Team ID, P12, password, profile,
  bundle, expiry, capability set, or certificate/profile pairing is wrong.
  Replace the environment secret; never weaken the validator to accept it.
- An already-used build number requires a source version/build update and a new
  tag. Dispatch-input changes cannot repair it.
- Revoke and replace the distribution certificate/profile or App Store Connect
  API key immediately after suspected disclosure, role change, or team-member
  departure. Update the protected environment and perform a new preflight run.
- Do not download signing material into a repository checkout or attach it to a
  GitHub issue, log, release, or Actions artifact.

The remaining submission blockers are intentionally owner-visible rather than
automated away: Apple-account authority, final store declarations, legal and
content-rights approval, current screenshots/media, TestFlight processing,
physical-device QA, App Review, and the explicit public-release decision.
