# INFINIDIVE Headless Soak Report

- Result: **PASS**
- Report transaction: `1051aee6fe155c7309536e30`
- Requested wall time: `90.00 seconds`
- Actual wall time: `90.18 seconds`
- Seed: `203541`
- Source fingerprint: `7fb2ddb25e31c6711e75c7c96fd9f7d6be00863c46b327c04c51a8698e7b9363`
- Source changed during run: `false`
- Environment: Godot `4.7.2-stable (official)`, display server `headless`
- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.

| Metric | Value |
|---|---:|
| Iterations | 1141 |
| Boss restarts | 115 |
| Dive transitions | 115 |
| Projectile pressure cycles | 1141 |
| Projectile travel models exercised | 7 / 7 |
| Player projectiles spawned | 70038 |
| Enemy projectiles spawned | 137588 |
| Peak simultaneous projectiles | 540 |
| Save writes / reloads | 58 / 0 |
| Offline events / reloads | 634 / 3 |
| Peak objects / nodes / orphan nodes | 1597 / 32 / 0 |
| Peak static memory | 39.10 MB |
| Post-warm-up memory delta | 0.09 MB |
| Post-warm-up memory slope | 0.213 MB/min |
| Failures | 0 |
