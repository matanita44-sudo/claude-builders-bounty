# INFINIDIVE Headless Soak Report

- Result: **PASS**
- Requested wall time: `1800.00 seconds`
- Actual wall time: `1800.02 seconds`
- Seed: `203541`
- Environment: Godot `4.7.2-stable (official)`, display server `headless`
- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.
- Source note: Godot validated the production snapshot loaded when the process started. Production files were edited concurrently later in the run, so this report does not validate those later edits; repeat after code freeze for Release Candidate evidence.

| Metric | Value |
|---|---:|
| Iterations | 32388 |
| Boss restarts | 3239 |
| Dive transitions | 3239 |
| Projectile pressure cycles | 32388 |
| Player projectiles spawned | 1987372 |
| Enemy projectiles spawned | 3904733 |
| Peak simultaneous projectiles | 540 |
| Save writes / reloads | 1620 / 27 |
| Offline events / reloads | 3759 / 29 |
| Peak objects / nodes / orphan nodes | 1588 / 30 / 0 |
| Peak static memory | 38.35 MB |
| Post-warm-up memory delta | 3.62 MB |
| Post-warm-up memory slope | 0.140 MB/min |
| Failures | 0 |
