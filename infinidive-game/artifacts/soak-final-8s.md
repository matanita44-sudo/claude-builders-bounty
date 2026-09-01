# INFINIDIVE Headless Soak Report

- Result: **PASS**
- Report transaction: `b04902b7a88fbfcb2eda26fe`
- Requested wall time: `8.00 seconds`
- Actual wall time: `8.24 seconds`
- Seed: `203541`
- Source fingerprint: `7fb2ddb25e31c6711e75c7c96fd9f7d6be00863c46b327c04c51a8698e7b9363`
- Source changed during run: `false`
- Environment: Godot `4.7.2-stable (official)`, display server `headless`
- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.

| Metric | Value |
|---|---:|
| Iterations | 91 |
| Boss restarts | 10 |
| Dive transitions | 10 |
| Projectile pressure cycles | 91 |
| Projectile travel models exercised | 7 / 7 |
| Player projectiles spawned | 5600 |
| Enemy projectiles spawned | 11031 |
| Peak simultaneous projectiles | 540 |
| Save writes / reloads | 6 / 0 |
| Offline events / reloads | 529 / 2 |
| Peak objects / nodes / orphan nodes | 1597 / 32 / 0 |
| Peak static memory | 38.89 MB |
| Post-warm-up memory delta | 0.00 MB |
| Post-warm-up memory slope | 0.005 MB/min |
| Failures | 0 |
