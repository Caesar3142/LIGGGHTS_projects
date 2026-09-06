# long-fiber-drop-to-ground

LIGGGHTS **DEM-only** case: **flexible rubber fibers** (bonded sphere chains) fall onto a **1×1 m** STL ground mesh tilted **~12°**, bend on impact, then settle.

Requires image **`liggghts-flex:local`** (granular bonds). Stock **`liggghts:local`** is rigid-only and cannot bend.

## Case overview

| Item | Value |
|------|--------|
| Input script | `simple_dropping_to_ground.liggghts` |
| Ground mesh | `1x1m-ground.stl` (ASCII, tilted ~12°) |
| Particles | Flexible bonded fibers: **~150 mm × 10 mm** (16 abutting spheres + 15 bonds) |
| Contact E / Poisson | 5×10⁶ Pa / 0.49 (rubber-like) |
| Bond Young’s / shear | **2×10⁵** Pa / auto from Poisson (**soft → bends easily**) |
| Restitution / friction | 0.80 / 0.70 |
| Contact model | Hertz + tangential history |
| Bond model | `bond_style gran` (Flexible Fibers) |
| Insertion | `insert/pack` (~25 fibers, random orientation) |
| Integrator | `nve/sphere` (spheres linked by soft bonds) |
| Timestep | 1×10⁻⁶ s |
| Dump interval | 1000 steps (0.001 s) |
| Run length | 3 000 000 steps (~3 s) |

Watch `ke` and `numbonds` in thermo. Bonds should stay near 25×15 = 375 if nothing breaks.

## Files

```
long-fiber-drop-to-ground/
├── Allrun.sh / Allclean.sh / Allpostprocess.sh
├── simple_dropping_to_ground.liggghts
├── dumpsToParaView
├── 1x1m-ground.stl
└── post/
```

Repo root also has `Dockerfile.flexible` → image `liggghts-flex:local`.

## Prerequisites

1. Docker Desktop running  
2. Build the flexible-fiber image once from the repo root:

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects
docker build --platform linux/amd64 -f Dockerfile.flexible -t liggghts-flex:local .
```

## How to run

### 1. Start the flexible container

```bash
docker run -it --rm --platform linux/amd64 \
  -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \
  liggghts-flex:local
```

### 2. Allrun (inside the container)

```bash
cd /simulation/long-fiber-drop-to-ground
./Allrun.sh
```

1. Prepare (`Allclean`)  
2. Run LIGGGHTS  
3. Post-process → `post/particles.pvd`

### 3. Exit

```bash
exit
```

## Post-process only

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects/long-fiber-drop-to-ground
./Allpostprocess.sh
```

Open `post/particles.pvd` in ParaView; color by **`mol`**. Fibers should visibly bend on ground impact.

## Useful tweaks

| Goal | Edit in input |
|------|----------------|
| **More flexible** | Lower `bond_youngs` (e.g. `1.e5`) |
| Stiffer / less bend | Raise `bond_youngs` (e.g. `1.e6`–`1.e7`) |
| More / fewer fibers | `particles_in_region` |
| Longer fiber | Add more spheres + bond pairs in the template |
| More bounce | Raise `restitution` |

## Related cases

| Case | Image | Notes |
|------|--------|--------|
| `simple-drop-to-ground/` | `liggghts:local` | Rigid spheres |
| `long-fiber-drop-to-ground/` | **`liggghts-flex:local`** | This flexible bonded-fiber case |
| `cyclone-separator/` | `cfdem:local` | CFD–DEM |
