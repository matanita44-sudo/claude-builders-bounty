# INFINIDIVE Headless Soak Report

- Result: **PASS**
- Report transaction: `994142d36b9310b4523a7b2f`
- Requested wall time: `8.00 seconds`
- Actual wall time: `8.05 seconds`
- Seed: `2039070`
- Source fingerprint: `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`
- Source changed during run: `false`
- Environment: Godot `4.7.2-stable (official)`, display server `headless`
- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.

| Metric | Value |
|---|---:|
| Iterations | 88 |
| Boss restarts | 9 |
| Dive transitions | 9 |
| Projectile pressure cycles | 88 |
| Projectile travel models exercised | 7 / 7 |
| Player projectiles spawned | 5444 |
| Enemy projectiles spawned | 10662 |
| Peak simultaneous projectiles | 540 |
| Save writes / reloads | 6 / 0 |
| Offline events / reloads | 529 / 2 |
| Peak objects / nodes / orphan nodes | 1597 / 32 / 0 |
| Peak static memory | 38.89 MB |
| Post-warm-up memory delta | 0.00 MB |
| Post-warm-up memory slope | 0.083 MB/min |
| Failures | 0 |
