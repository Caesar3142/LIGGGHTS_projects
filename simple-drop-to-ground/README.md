# simple-drop-to-ground

LIGGGHTS case: **20 mm steel spheres** fall **0.5 m** onto a **1×1 m** STL ground mesh, bounce, and settle.

## Case overview

| Item | Value |
|------|--------|
| Input script | `simple_dropping_to_ground.liggghts` |
| Ground mesh | `1x1m-ground.stl` (ASCII, z = 0, 0–1 m in x/y) |
| Particles | Steel spheres, diameter **20 mm** (0.02 m) |
| Density | 7850 kg/m³ |
| Young’s modulus / Poisson | 2.1×10¹¹ Pa / 0.30 (`hard_particles yes` required) |
| Restitution / friction | 0.7 / 0.15 |
| Contact model | Hertz + tangential history |
| Drop height | 0.5 m (particle surface above ground) |
| Gravity | 9.81 m/s² straight down |
| Timestep | 1×10⁻⁶ s (stiff steel contacts) |
| Run length | 2 000 000 steps (~2 s physical time) |
| Outputs | `post/trajectory.dump`, `post/ground_mesh_*.stl`, logs |

Watch kinetic energy (`ke`) in the thermo output. When it stays near zero, particles have settled. Increase `run` if they are still bouncing.

## Files

```
simple-drop-to-ground/
├── README.md
├── simple_dropping_to_ground.liggghts   # input script
├── 1x1m-ground.stl                      # ground mesh used by the run (ASCII)
├── dumpsToParaView                      # convert dump → ParaView CSV frames
├── log.liggghts / screen.log            # created when you run (gitignored)
└── post/                                # dumps & ParaView frames (gitignored)
```

**Note:** LIGGGHTS can fail on some binary STLs (`mesh empty / dimensions too small`). This case uses an ASCII mesh. Prefer ASCII when swapping in a new ground file.

## Prerequisites

1. Docker Desktop running on your Mac  
2. Project image built once from the repo root:

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects
docker build --platform linux/amd64 -t liggghts:local .
```

See also `../LIGGGHTS_Mac_Docker_notes.md`.

## How to run

### 1. Start the container (Mac terminal)

```bash
docker run -it --rm --platform linux/amd64 \
  -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \
  liggghts:local
```

Your Mac project folder is mounted at `/simulation` inside the container.

### 2. Run the case (inside the container)

```bash
cd /simulation/simple-drop-to-ground
rm -rf post
liggghts -in simple_dropping_to_ground.liggghts -log log.liggghts | tee screen.log
```

You should see mesh processing steps **1/3, 2/3, 3/3**, then the time-step loop.

Results appear on your Mac under this folder immediately (no `docker cp` needed).

### 3. Exit the container

```bash
exit
```

## Convert dumps for ParaView (on Mac)

From the case folder:

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects/simple-drop-to-ground
./dumpsToParaView
```

Frames are written into `post/`.

### View in ParaView

1. **File → Open** → select the `frame_*.csv` series → Apply  
2. Filter **Table To Points** — set X/Y/Z to `x` / `y` / `z`  
3. Optionally open `ground_mesh_0.stl` (or `1x1m-ground.stl`) to show the ground  
4. Use Glyph → Sphere with scale mode by `radius` if you want true 20 mm balls

## Useful tweaks

| Goal | Edit in `simple_dropping_to_ground.liggghts` |
|------|-----------------------------------------------|
| Longer settle time | Increase `run` (e.g. `3000000`) |
| More / fewer particles | Change `spawner` region or `lattice` spacing |
| Softer bounce | Lower `restitution` |
| More / less slipping | Lower / raise `friction` |
| Faster (softer) DEM | Lower `youngs` (e.g. `1e8`) and raise `timestep` |
| Different ground | Replace `1x1m-ground.stl` (ASCII preferred); keep name or update the `mesh/surface file ...` line |
| Dump more often | Lower the dump interval (currently `10000`) |
