# INFINIDIVE Headless Soak Report

- Result: **PASS**
- Report transaction: `b5a5db690e1513095a2cf63f`
- Requested wall time: `8.00 seconds`
- Actual wall time: `8.01 seconds`
- Seed: `203541`
- Source fingerprint: `8e9810de2615332713f86f47bf2f28f38728fb75e51ea5bfaf2d16760927d863`
- Source changed during run: `false`
- Environment: Godot `4.7.2-stable (official)`, display server `headless`
- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.

| Metric | Value |
|---|---:|
| Iterations | 87 |
| Boss restarts | 9 |
| Dive transitions | 9 |
| Projectile pressure cycles | 87 |
| Projectile travel models exercised | 7 / 7 |
| Player projectiles spawned | 5394 |
| Enemy projectiles spawned | 10541 |
| Peak simultaneous projectiles | 540 |
| Save writes / reloads | 6 / 0 |
| Offline events / reloads | 529 / 2 |
| Peak objects / nodes / orphan nodes | 1597 / 32 / 0 |
| Peak static memory | 38.87 MB |
| Post-warm-up memory delta | 0.03 MB |
| Post-warm-up memory slope | 0.508 MB/min |
| Failures | 0 |
