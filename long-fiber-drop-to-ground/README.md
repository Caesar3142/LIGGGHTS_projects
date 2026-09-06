# long-fiber-drop-to-ground

LIGGGHTS **DEM-only** case: **rigid long fibers** (multisphere chains) fall onto a **1×1 m** STL ground mesh tilted **~12°**, then slide downhill and settle.

Use image **`liggghts:local`** for this case. For CFD–DEM (e.g. `fluidized-bed/`), use **`cfdem:local`** instead — see `../LIGGGHTS_Mac_Docker_notes.md`.

## Case overview

| Item | Value |
|------|--------|
| Input script | `simple_dropping_to_ground.liggghts` |
| Ground mesh | `1x1m-ground.stl` (ASCII, 1×1 m, tilted ~12°, high at x=0 → low at x=1) |
| Particles | Rigid multisphere fibers: **~152 mm × 10 mm** (20 overlapping spheres) |
| Fiber template | `data/fiber.multisphere` |
| Density | 1100 kg/m³ (rubber-like) |
| Young’s modulus / Poisson | 5×10⁶ Pa / 0.49 |
| Restitution / friction | 0.80 / 0.70 (bouncy, grippy) |
| Contact model | Hertz + tangential history |
| Insertion | `insert/pack` (~40 fibers above the high end of the ramp) |
| Integrator | `fix multisphere` (rigid body, not `nve/sphere`) |
| Gravity | 9.81 m/s² straight down |
| Timestep | 1×10⁻⁶ s (fine enough to resolve soft bounce) |
| Dump interval | 1000 steps (0.001 s) → smooth ParaView bounce |
| Run length | 3 000 000 steps (~3 s physical time) |
| Outputs | `post/dump*.liggghts_run`, `post/ground_mesh_*.stl`, logs |

Watch kinetic energy (`ke`) in the thermo output. When it stays near zero, fibers have settled. Increase `run` if they are still bouncing.

## Files

```
long-fiber-drop-to-ground/
├── README.md
├── Allrun.sh                            # prepare + run + post-process
├── Allclean.sh                          # wipe post/ dumps & logs
├── Allpostprocess.sh                    # dump*.liggghts_run → particles.pvd
├── simple_dropping_to_ground.liggghts   # input script
├── data/fiber.multisphere              # sphere-chain geometry for one fiber
├── 1x1m-ground.stl                      # ground mesh used by the run (ASCII)
├── dumpsToParaView                      # DEM dump converter
├── log.liggghts / screen.log            # created when you run
└── post/                                # dumps & ParaView outputs
```

**Note:** LIGGGHTS can fail on some binary STLs (`mesh empty / dimensions too small`). This case uses an ASCII mesh. Prefer ASCII when swapping in a new ground file.

## Prerequisites

1. Docker Desktop running on your Mac  
2. DEM image built once from the repo root:

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects
docker build --platform linux/amd64 -t liggghts:local .
```

## How to run

### 1. Start the container (Mac terminal)

```bash
docker run -it --rm --platform linux/amd64 \
  -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \
  liggghts:local
```

### 2. Allrun (inside the container)

```bash
cd /simulation/long-fiber-drop-to-ground
./Allrun.sh
```

This does:

1. **Prepare** — `./Allclean.sh` (clears old `post/` dumps + logs, recreates `post/`)
2. **Run** — `liggghts -in simple_dropping_to_ground.liggghts`
3. **Post-process** — `./Allpostprocess.sh` → `post/particles.pvd`

Dumps appear as `post/dump0.liggghts_run`, `post/dump1000.liggghts_run`, … (same naming as `cyclone-separator/DEM`).

Manual pieces if needed:

```bash
./Allclean.sh
liggghts -in simple_dropping_to_ground.liggghts -log log.liggghts | tee screen.log
./Allpostprocess.sh
```

### 3. Exit the container

```bash
exit
```

## Post-process only (Mac or container)

If dumps already exist:

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects/long-fiber-drop-to-ground
./Allpostprocess.sh
# or: ./dumpsToParaView --step0 0 --dt 1e-6
```

This writes:

- `post/particles_*.vtp`
- `post/particles.pvd`

### View in ParaView

1. **File → Open** → `post/particles.pvd` → Apply  
2. Representation = **Point Gaussian** (or Glyph → Sphere scaled by `radius`)  
3. Color by **`mol`** (fiber body id) or **`vmag`**  
4. Optionally open `post/ground_mesh_0.stl`  

Do **not** open the raw dump files or CSV series for time playback — use **`particles.pvd`**.

## Useful tweaks

| Goal | Edit |
|------|------|
| Longer / shorter fibers | Edit `data/fiber.multisphere` and match `nspheres` in the input |
| More / fewer fibers | Change `particles_in_region` |
| Less / more bounce | Lower / raise `restitution` (default 0.80) |
| Dump more often | Lower the dump interval (currently `1000` → 0.001 s) |
| Different ground | Replace `1x1m-ground.stl` (ASCII preferred) |

## Related cases

| Case | Image | Notes |
|------|--------|--------|
| `simple-drop-to-ground/` | `liggghts:local` | Spherical steel balls on the same ground |
| `cyclone-separator/` | `cfdem:local` | CFD–DEM; DEM post uses the same `dump*.liggghts_run` → `particles.pvd` path |
| `long-fiber-drop-to-ground/` | `liggghts:local` | This rigid multisphere fiber case |
