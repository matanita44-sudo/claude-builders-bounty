# INFINIDIVE Headless Soak Report

- Result: **PASS**
- Report transaction: `5c047f1a630e8e1de5c5ffff`
- Requested wall time: `1800.00 seconds`
- Actual wall time: `1800.04 seconds`
- Seed: `203541`
- Source fingerprint: `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`
- Source changed during run: `false`
- Environment: Godot `4.7.2-stable (official)`, display server `headless`
- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.

| Metric | Value |
|---|---:|
| Iterations | 26676 |
| Boss restarts | 2668 |
| Dive transitions | 2668 |
| Projectile pressure cycles | 26676 |
| Projectile travel models exercised | 7 / 7 |
| Player projectiles spawned | 1636943 |
| Enemy projectiles spawned | 3216180 |
| Peak simultaneous projectiles | 540 |
| Save writes / reloads | 1335 / 22 |
| Offline events / reloads | 3188 / 24 |
| Peak objects / nodes / orphan nodes | 1597 / 32 / 0 |
| Peak static memory | 42.78 MB |
| Post-warm-up memory delta | 3.50 MB |
| Post-warm-up memory slope | 0.081 MB/min |
| Failures | 0 |
