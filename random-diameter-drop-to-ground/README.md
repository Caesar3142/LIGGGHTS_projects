# random-diameter-drop-to-ground

LIGGGHTS case: **steel spheres with diameters from 5–30 mm** fall **~0.5 m** onto a **1×1 m** ground tilted **~12°**, then slide and settle.

## Case overview

| Item | Value |
|------|--------|
| Input script | `random_diameter_drop_to_ground.liggghts` |
| Ground mesh | `1x1m-ground.stl` (ASCII, 1×1 m, tilted ~12°) |
| Diameter | **5–30 mm** via 11 discrete bins (equal number ≈9% each) |
| Insert | `insert/pack` → 250 particles |
| Domain | Extends **1 m** beyond the old box so off-plate particles stay visible |
| Material | Steel: ρ=7850, E=2.1×10¹¹, ν=0.30, e=0.7, μ=0.15 |
| Contact model | Hertz + tangential history (`hard_particles yes`) |
| Timestep | 5×10⁻⁷ s (set by smallest 5 mm particles) |
| Run length | 6 000 000 steps (~3 s physical time) |
| Outputs | `post/trajectory.dump`, `post/ground_mesh_*.stl`, logs |

**Why discrete bins?** This LIGGGHTS package does not support continuous `diameter range` / random radius styles. Bins are 5, 7.5, …, 30 mm with mass fractions ∝ d³ so each size appears with roughly equal count.

## Files

```
random-diameter-drop-to-ground/
├── README.md
├── random_diameter_drop_to_ground.liggghts
├── 1x1m-ground.stl
├── dumpsToParaView
└── post/                         # created when you run
```

## How to run

### 1. Start the container (Mac)

```bash
docker run -it --rm --platform linux/amd64 \
  -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \
  liggghts:local
```

### 2. Run the case (inside the container)

```bash
cd /simulation/random-diameter-drop-to-ground
mkdir -p post && rm -rf post/*
liggghts -in random_diameter_drop_to_ground.liggghts -log log.liggghts | tee screen.log
```

You should see the diameter distribution printout (mass% and number%), then insertion of 250 particles.

### 3. Convert for ParaView (on Mac)

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects/random-diameter-drop-to-ground
./dumpsToParaView
```

In ParaView: open `frame_*.csv` → **Table To Points** → Glyph spheres scaled by `radius`. Also open `ground_mesh_0.stl`.

## Useful tweaks

| Goal | Edit |
|------|------|
| More / fewer particles | `particles_in_region` on `insert/pack` |
| Different size bounds | Change template radii and mass fractions |
| Longer settle | Increase `run` |
| Steeper ramp | Reuse / regenerate STL from `simple-drop-to-ground` |
