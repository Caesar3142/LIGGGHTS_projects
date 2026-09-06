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
| Density | 1200 kg/m³ |
| Young’s modulus / Poisson | 5×10⁸ Pa / 0.30 |
| Restitution / friction | 0.3 / 0.4 |
| Contact model | Hertz + tangential history |
| Insertion | `insert/pack` (~40 fibers above the high end of the ramp) |
| Integrator | `fix multisphere` (rigid body, not `nve/sphere`) |
| Gravity | 9.81 m/s² straight down |
| Timestep | 5×10⁻⁶ s |
| Dump interval | 10000 steps (0.05 s) → `post/dump*.liggghts_run` |
| Run length | 600 000 steps (~3 s physical time) |
| Outputs | `post/dump*.liggghts_run`, `post/ground_mesh_*.stl`, logs |

Watch kinetic energy (`ke`) in the thermo output. When it stays near zero, fibers have settled. Increase `run` if they are still bouncing.

## Files

```
long-fiber-drop-to-ground/
├── README.md
├── simple_dropping_to_ground.liggghts   # input script
├── data/fiber.multisphere              # sphere-chain geometry for one fiber
├── 1x1m-ground.stl                      # ground mesh used by the run (ASCII)
├── dumpsToParaView                      # dump*.liggghts_run → particles.pvd
├── Allpostprocess.sh                    # thin wrapper (same idea as cyclone DEM post)
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

### 2. Run the case (inside the container)

```bash
cd /simulation/long-fiber-drop-to-ground
mkdir -p post
rm -rf post/dump*.liggghts_run post/particles_* post/particles.pvd post/ground_mesh_*.stl
liggghts -in simple_dropping_to_ground.liggghts -log log.liggghts | tee screen.log
```

Dumps appear as `post/dump0.liggghts_run`, `post/dump10000.liggghts_run`, … (same naming as `cyclone-separator/DEM`).

### 3. Exit the container

```bash
exit
```

## Post-process (Mac — cyclone DEM strategy)

Same pattern as `cyclone-separator` with DEM dumps only:

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects/long-fiber-drop-to-ground
./Allpostprocess.sh
# or directly:
# ./dumpsToParaView --step0 0 --dt 5e-6
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
| Softer bounce | Lower `restitution` |
| Dump more often | Lower the dump interval (currently `10000`) |
| Different ground | Replace `1x1m-ground.stl` (ASCII preferred) |

## Related cases

| Case | Image | Notes |
|------|--------|--------|
| `simple-drop-to-ground/` | `liggghts:local` | Spherical steel balls on the same ground |
| `cyclone-separator/` | `cfdem:local` | CFD–DEM; DEM post uses the same `dump*.liggghts_run` → `particles.pvd` path |
| `long-fiber-drop-to-ground/` | `liggghts:local` | This rigid multisphere fiber case |
