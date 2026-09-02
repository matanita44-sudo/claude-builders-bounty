# INFINIDIVE Headless Soak Report

- Result: **PASS**
- Report transaction: `9f396a0becf39225c7580401`
- Requested wall time: `1800.00 seconds`
- Actual wall time: `1800.04 seconds`
- Seed: `203541`
- Source fingerprint: `1db2d97aa0852a415ee4a76e3d4be6ea20949140dfcdee46e49d295e55525e8e`
- Source changed during run: `false`
- Environment: Godot `4.7.2-stable (official)`, display server `headless`
- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.

| Metric | Value |
|---|---:|
| Iterations | 27043 |
| Boss restarts | 2705 |
| Dive transitions | 2705 |
| Projectile pressure cycles | 27043 |
| Projectile travel models exercised | 7 / 7 |
| Player projectiles spawned | 1659358 |
| Enemy projectiles spawned | 3260252 |
| Peak simultaneous projectiles | 540 |
| Save writes / reloads | 1353 / 22 |
| Offline events / reloads | 3224 / 24 |
| Peak objects / nodes / orphan nodes | 1597 / 32 / 0 |
| Peak static memory | 42.79 MB |
| Post-warm-up memory delta | 3.14 MB |
| Post-warm-up memory slope | 0.085 MB/min |
| Failures | 0 |
