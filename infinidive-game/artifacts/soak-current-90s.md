# INFINIDIVE Headless Soak Report

- Result: **PASS**
- Report transaction: `98e69a9b42dd1314f6a16cb9`
- Requested wall time: `90.00 seconds`
- Actual wall time: `90.04 seconds`
- Seed: `2039070`
- Source fingerprint: `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`
- Source changed during run: `false`
- Environment: Godot `4.7.2-stable (official)`, display server `headless`
- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.

| Metric | Value |
|---|---:|
| Iterations | 1166 |
| Boss restarts | 117 |
| Dive transitions | 117 |
| Projectile pressure cycles | 1166 |
| Projectile travel models exercised | 7 / 7 |
| Player projectiles spawned | 71549 |
| Enemy projectiles spawned | 140575 |
| Peak simultaneous projectiles | 540 |
| Save writes / reloads | 60 / 1 |
| Offline events / reloads | 637 / 3 |
| Peak objects / nodes / orphan nodes | 1597 / 32 / 0 |
| Peak static memory | 39.12 MB |
| Post-warm-up memory delta | 0.09 MB |
| Post-warm-up memory slope | 0.209 MB/min |
| Failures | 0 |
