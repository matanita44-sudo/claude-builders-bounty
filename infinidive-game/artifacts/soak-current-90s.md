# INFINIDIVE Headless Soak Report

- Result: **PASS**
- Report transaction: `26dad83d28067418d76982a3`
- Requested wall time: `90.00 seconds`
- Actual wall time: `90.05 seconds`
- Seed: `203541`
- Source fingerprint: `e942db6f8a0f1a47518e8afb468f77c651001a2028fcad0820e71c4d993a6382`
- Source changed during run: `false`
- Environment: Godot `4.7.2-stable (official)`, display server `headless`
- Scope: Linux Godot headless structural stability only; this is not physical-device performance evidence.

| Metric | Value |
|---|---:|
| Iterations | 1169 |
| Boss restarts | 117 |
| Dive transitions | 117 |
| Projectile pressure cycles | 1169 |
| Projectile travel models exercised | 7 / 7 |
| Player projectiles spawned | 71726 |
| Enemy projectiles spawned | 140923 |
| Peak simultaneous projectiles | 540 |
| Save writes / reloads | 60 / 1 |
| Offline events / reloads | 637 / 3 |
| Peak objects / nodes / orphan nodes | 1597 / 32 / 0 |
| Peak static memory | 39.10 MB |
| Post-warm-up memory delta | 0.09 MB |
| Post-warm-up memory slope | 0.209 MB/min |
| Failures | 0 |
