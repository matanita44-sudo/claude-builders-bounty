# INFINIDIVE Headless Soak Report

- Result: **PASS**
- Report transaction: `9ac05a1b4bcc696001e5a6e7`
- Requested wall time: `8.00 seconds`
- Actual wall time: `8.03 seconds`
- Seed: `203541`
- Source fingerprint: `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`
- Source changed during run: `false`
- Environment: Godot `4.7.2-stable (official)`, display server `headless`
- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.

| Metric | Value |
|---|---:|
| Iterations | 86 |
| Boss restarts | 9 |
| Dive transitions | 9 |
| Projectile pressure cycles | 86 |
| Projectile travel models exercised | 7 / 7 |
| Player projectiles spawned | 5345 |
| Enemy projectiles spawned | 10421 |
| Peak simultaneous projectiles | 540 |
| Save writes / reloads | 6 / 0 |
| Offline events / reloads | 529 / 2 |
| Peak objects / nodes / orphan nodes | 1597 / 32 / 0 |
| Peak static memory | 38.87 MB |
| Post-warm-up memory delta | 0.03 MB |
| Post-warm-up memory slope | 0.501 MB/min |
| Failures | 0 |
