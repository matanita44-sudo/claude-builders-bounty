# INFINIDIVE Privacy Data Map

**Document status:** implementation-aligned pre-release draft\
**Code reviewed:** project version `0.1.0`\
**Review date:** 2026-09-01\
**Owner/contact:** Matan — `matanita44@gmail.com`

This document maps what the current INFINIDIVE code and public browser pre-release do. The GitHub Pages preview is live, but this document is not evidence of an App Store build, Google Play build, backend, analytics transport, or signed native release. Re-check the final signed binaries and every bundled SDK before completing store privacy forms.

## Current privacy posture

- Core play is local and offline.
- The game does not require an account, name, email address, or login.
- No backend, leaderboard transport, cloud save, fetched remote configuration, advertising, billing, crash-reporting, or third-party analytics SDK is connected.
- A local-only leaderboard service and bundled fail-closed configuration service are autoloaded. Every completed run is validated locally, but only accepted Daily/Friend challenges write an unverified summary to the outbox under a canonical challenge ID. Story/Abyss results do not enter the outbox. Neither service contains a network client or endpoint.
- The analytics abstraction has **no network transport**. Consent defaults to off. If the internal setting is enabled, events are written only to a local queue.
- Friend Rift codes are generated and parsed locally. A code is written to the system clipboard only after the player explicitly selects a copy/share action.
- Settings includes user-initiated Support and Privacy buttons. On native platforms they open `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` plus the selected page in the system browser; no gameplay data or identifier is appended to the URL. The game, privacy, and support pages at that origin are deployed and return HTTP 200.
- The game code does not request contacts, precise or approximate location, camera, microphone, photo library, advertising identifiers, or payment data. Android presets request only the normal `android.permission.VIBRATE` permission for optional haptics; it has no runtime permission prompt and does not collect or transmit data.
- Local save checksums detect damage or tampering; they are not encryption.

## Data-flow inventory

| Flow | Data involved | Trigger and purpose | Storage and retention | Leaves the device? | User control |
|---|---|---|---|---|---|
| Progress save | Bio-Matter, Core Shards, unlocks, selected weapon, permanent upgrades, Nest stage, boss clears, difficulty progress, completed achievements and their progress, discovered mutations, high scores, tutorial state, cosmetic choice, contract progress, run/win totals, Abyss unlock, processed run IDs, meta-goal reward-ledger keys, and bounded SHA-256 event receipts (maximum 4,096) | Created during play so progress survives relaunch and completed run/meta rewards are not banked twice | Versioned JSON in Godot `user://`, plus a temporary file and one rotating backup; retained until local app/site data is cleared | No | Clear the app's storage, uninstall the native app, or clear this site's stored data in the browser |
| Settings save | Audio levels, haptics, screen shake, reduced motion, projectile contrast, damage flash, control sensitivity, dash method, handedness, language, assist values, aim assist, analytics consent field | Saved when settings change | Stored inside the local progress save; same retention as the progress save | No | Change exposed settings; clear local app/site data to delete all settings |
| Optional analytics queue | Allowlisted gameplay event name, primitive event properties, locally generated session ID, UTC timestamp | Recorded only when the player enables `analytics_opt_in` in Settings; intended for future product analysis | `user://analytics_queue.json`, capped at 500 events | **No. There is no uploader, HTTP request, vendor SDK, or backend endpoint.** | Consent defaults to false and can be changed in Settings. Turning it off stops new events without deleting old entries; confirmed Reset Progress or platform/site-data clearing deletes the queue |
| Offline Daily/Friend leaderboard outbox | Run ID, mode, canonical challenge ID/day, boss, weapon, difficulty, deterministic seed, canonical modifiers/targets, score, duration, win state, destroyed organ IDs, mutation IDs, bounded event counters/major-event IDs, event digest, client version, local submission ID/status/attempt count | Every completed run calls the local validation API after reward banking. Only accepted Daily/Friend summaries enter the future-adapter outbox; Story/Abyss calls return local-only without queueing | `user://infinidive_leaderboard_queue.json`, plus temporary and rotating backup files; default cap 256; checksummed envelope | **No. `flush_pending()` deliberately sends zero records and reports transport disabled/unavailable.** | There is no submit toggle or online leaderboard. Confirmed Reset Progress idempotently removes the primary, backup, and temporary outbox files; platform/site-data clearing also removes them |
| Bundled feature configuration | Boolean feature flags and numeric validation/queue limits from `res://data/remote_config.json` | Loaded at boot to keep unavailable online and monetization features disabled | Packaged read-only project resource and in-memory snapshot | No; there is no remote fetch, provider, or endpoint | Not player-editable; malformed/missing values fall back to safe local defaults |
| Friend Rift code | Boss, deterministic seed, weapon, difficulty, up to four modifiers, optional target score and target time | Created when the player chooses to create/share a Friend Rift; decoded when the player pastes a code | Held in memory; copied to the system clipboard on explicit action | Not by the game. The player may choose to paste the code into another app or service, which has its own privacy practices | Do not copy/share the code; replace or clear clipboard contents using device controls |
| Daily Rift seed | Current UTC calendar date | Produces the same deterministic daily challenge locally | Computed in memory | No | No account or network sync is involved |
| Run/session identifiers | System time, engine tick count, random number, run seed, boss ID | Distinguishes local runs and prevents duplicate local reward banking; identifies entries in the optional local analytics queue | Run IDs are stored in the progress save; session IDs are stored only if local analytics is enabled | No | Clear local app/site data |
| Device interaction | Touch/mouse input, viewport dimensions, safe-area insets, focus/background notifications, optional vibration request | Controls the game, lays out UI around notches, pauses on focus loss, and provides haptic feedback. Android declares the normal `android.permission.VIBRATE` permission; it triggers no runtime consent dialog. | Processed ephemerally in memory | No; vibration does not collect or transmit information | Disable haptics in settings; platform controls govern input and vibration |
| Support/privacy page opening | Only the fixed page path; no run, profile, session, or challenge data is appended | Player explicitly taps Support or Privacy in Settings; native builds ask the system browser to open `https://matanita44-sudo.github.io/claude-builders-bounty/infinidive/` plus the page name, while Web uses a relative page | No game-side record | The browser makes the ordinary web request, so the host can receive request metadata | Do not open the page; browser and host controls apply after opening |
| Support correspondence | Email address, message content, and any attachment a person voluntarily sends | The static support page opens the person's mail client to request help | Stored by the sender's and recipient's email providers according to their settings and policies; retained only as reasonably needed to answer and document the request | Yes, but outside the game binary and only when the person chooses to send email | Do not include unnecessary personal data; request deletion at `matanita44@gmail.com` |
| Public web hosting logs | The browser pre-release is deployed to GitHub Pages. GitHub may process ordinary request data such as IP address, timestamp, requested URL, and browser user-agent | Serving the game, privacy page, or support page | GitHub-dependent; deployment is verified, but host-log retention was not independently verified in this repository | Potentially, at the hosting layer | Review current GitHub terms before store release; browser controls may clear local site data but not host logs |

## Optional local analytics details

The following event names are allowlisted in `scripts/services/analytics_service.gd`:

`app_open`, `session_start`, `tutorial_start`, `tutorial_step`, `tutorial_complete`, `first_shot`, `first_damage_taken`, `first_dash`, `first_breach`, `first_dive`, `organ_destroyed`, `boss_phase_reached`, `mutation_offered`, `mutation_selected`, `player_death`, `instant_retry`, `run_complete`, `weapon_selected`, `forge_purchase`, `nest_upgrade`, `daily_rift_start`, `daily_rift_complete`, `friend_rift_created`, `friend_rift_opened`, `abyss_depth_reached`, `settings_changed`, and `session_end`.

Only string, Boolean, integer, and floating-point properties are accepted. Property keys are truncated to 48 characters. Current call sites may attach gameplay values such as version, boss, weapon, mutation, seed, elapsed time, organ order, death cause, depth, or the name of a changed setting. They do not attach a name, email address, device advertising ID, contact list, or precise location.

`export_offline_queue()` returns an in-memory copy to local code. Despite the method name, it does not upload or write an external export.

## Information not requested or collected by the game code

- Name, email address, postal address, phone number, or date of birth
- Account credentials, passwords, or two-factor authentication codes
- Contacts or social graph
- Precise or approximate location
- Camera, microphone, photos, or videos
- Health, fitness, biometric, or sensor history
- Financial or payment information
- Advertising ID, cross-app tracking identifier, or advertising profile
- Browsing history or search history
- User-generated chat, voice, or public profile content
- Purchase history, because purchases are not implemented

The final Android debug export was inspected and requests exactly `android.permission.VIBRATE`; no other permission appears in that artifact. Full iOS export failed on the blank Team ID; a fresh current-source PCK was assembled into the retained unsigned scaffold, whose native privacy-manifest structure was not regenerated by a successful current-source project export. Both final binaries must be audited after production export/signing and whenever export templates or SDKs change, because the final AAB/archive can differ from development artifacts.

## Storage and security notes

- The primary save uses a temporary-file write, a backup rotation, a schema version, and a SHA-256 checksum before promotion.
- The checksum is an integrity mechanism, **not encryption or authentication**. A person with access to app storage may be able to read or modify local JSON.
- Friend Rift codes use a short checksum to reject accidental corruption and simple edits. They are not secrets, identity credentials, or cryptographically authenticated scores.
- Do not place personal or confidential information in a Friend Rift code; the format has no field for it.
- Rooted/jailbroken devices, shared OS accounts, browser developer tools, device backups, or compromised devices can expose local files outside the game's control.

## Retention and deletion

The current game has no server-side player record to delete.

- **iOS/Android:** uninstall INFINIDIVE or use the operating system's app-storage controls. Clearing storage removes local progress, settings, backups, any local analytics queue, and any local leaderboard outbox.
- **Web preview:** clear stored site data for the exact hosting origin. This permanently removes progress for that origin.
- **In-game reset:** Settings exposes Reset Progress behind a confirmation. It replaces the current profile and recovery backup with clean defaults, idempotently deletes `analytics_queue.json`, and idempotently deletes the Daily/Friend leaderboard outbox primary, backup, and temporary files. No server-side record is affected because no backend record exists. Operating-system/app or browser site-storage controls remain the broadest way to clear any platform-managed cache or future file not covered by the reviewed code.
- **Support email:** request deletion of a support thread by emailing `matanita44@gmail.com`. Some records may need to be retained where legally required or necessary to resolve abuse/security issues.

Deletion of local data is irreversible unless the platform independently restores a device backup. There is no cloud-save recovery in the reviewed build.

## Draft store disclosures for the current code

These are implementation notes, not submitted store answers.

### Apple App Privacy

Apple currently defines “collect” as transmitting data off the device in a way that makes it accessible to the developer or a third party for longer than necessary to service the request. On that definition, a final native binary identical to the reviewed code is a candidate for **Data Not Collected** and **no tracking**: gameplay, saves, and the optional analytics queue remain on device.

This answer must change if the final binary uploads analytics or crash data, connects leaderboards/cloud save, embeds an online service, adds ads or purchases, or bundles any SDK that transmits data.

### Google Play Data safety

Google currently defines collection as transmitting data from the app off a user's device and excludes data that is only accessed or processed on device. On that definition, a final Android binary identical to the reviewed code is a candidate for:

- Does the app collect or share required user data types? **No**
- Data shared with third parties by the app? **No**
- Contains ads? **No**
- Account creation or account deletion requirement? **Not applicable; there is no account**

The final answer must represent the union of practices in every version distributed under the package name and every bundled SDK. Re-audit the produced AAB, manifest, libraries, and all active Play tracks before submission.

## Change-control triggers

Review this map and both public pages before merging or enabling any of the following:

1. Analytics or crash-report upload
2. Leaderboard network transport, remote challenges, cloud save, fetched remote configuration, authentication, or public ranking UI
3. Ads, attribution, billing, purchases, or restore-purchase support
4. Push notifications or deep-link tracking
5. Any third-party SDK, embedded web view, or externally loaded script
6. Account, nickname, feedback form, replay upload, result-card upload, or video export to a service
7. A change of public host or support platform, or a material change to request-log or ticket-retention practices
8. New permissions, including camera, microphone, photos, contacts, or location

The release gate owner must compare this document with the exact signed binary, not only the source tree.

## Code evidence

| Evidence | Relevant behavior |
|---|---|
| `scripts/services/save_manager.gd` | Local profile fields, versioned envelope, checksum, temporary write, backup, migration, reset function |
| `scripts/services/settings_manager.gd` | Local setting application and optional device vibration |
| `scripts/services/analytics_service.gd` | Consent default dependency, event allowlist, local queue, 500-event cap, idempotent queue deletion, and no transport |
| `scripts/services/leaderboard_service.gd` | Validated local run-summary schema, deduplication, 256-entry default cap, checksummed atomic outbox/backup, idempotent primary/backup/temporary cleanup, local ranking, and deliberately unavailable transport |
| `scripts/services/remote_config_service.gd` and `data/remote_config.json` | Bundled fail-closed flags and limits; no HTTP client, endpoint, or remote fetch |
| `scripts/core/challenge_code.gd` | Local deterministic Daily seed and Friend Rift encoding/validation |
| `scripts/ui/nest_view.gd` | Explicit Friend Rift clipboard action, exposed settings, confirmed Reset Progress orchestration across profile/analytics/leaderboard stores, and player-initiated Support/Privacy browser links |
| `scripts/gameplay/run_scene.gd` | Local run IDs, local analytics call-site properties, automatic completed-run submission to the offline outbox, and result-code clipboard action |
| `scripts/ui/safe_area_helper.gd` | Native display-safe-area and Web CSS-safe-area reads |
| `web/custom_shell.html` | Same-origin game bootstrap and safe-area probe; no cookies, analytics, or third-party script |
| `project.godot` | Disabled motion sensors and configured local autoload services |
| `export_presets.cfg` | Current export settings; blank camera/microphone/photo usage descriptions; must be checked against generated native artifacts |

## Official platform references

Reviewed 2026-09-01:

- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- Apple User Privacy and Data Use: https://developer.apple.com/app-store/user-privacy-and-data-use/
- Google Play Data safety form guidance: https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
- Google Play content rating requirements: https://support.google.com/googleplay/android-developer/answer/9859655?hl=en
- GitHub General Privacy Statement for the configured Pages host: https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement

Platform rules change. Re-open the official sources in the relevant store console immediately before submission.
