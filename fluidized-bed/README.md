# fluidized-bed

CFDEM®coupling case: **gas–solid fluidized bed** (OpenFOAM `cfdemSolverPiso` ↔ LIGGGHTS).

Adapted from [CFDEMcoupling-PUBLIC `ErgunTestMPI`](https://github.com/CFDEMproject/CFDEMcoupling-PUBLIC/tree/master/tutorials/cfdemSolverPiso/ErgunTestMPI) with a taller freeboard and inlet velocity above \(U_{mf}\).

**Verified working** on Mac with Docker image **`cfdem:local`**. Do **not** use `liggghts:local` (DEM-only).

## Case overview

| Item | Value |
|------|--------|
| Solver | `cfdemSolverPiso` (4-way CFD–DEM) |
| Column | Cylinder, D ≈ **27.6 mm**, H = **150 mm** |
| Particles | ~**8000** spheres, d = **1 mm**, ρ = **2000 kg/m³** |
| Contact | Hertz + tangential history (soft demo solids, E = 5×10⁶ Pa) |
| Fluid (demo) | ρ = 10 kg/m³, ν = 1.5×10⁻⁴ m²/s (not real air) |
| Inlet U | Ramps **0.02 → 0.15 m/s** (z+) over 0.2 s |
| CFD Δt / write | 5×10⁻⁴ s / every **0.01 s** |
| DEM Δt / dump | 1×10⁻⁵ s / every **1000** steps (= **0.01 s**) |
| Coupling | `couple_every 100` (DEM); `couplingInterval 50` (CFD) |
| End time | **5.0 s** |
| MPI | **4** ranks (`processors 2 2 1`; `decomposeParDict` = 4) |

Demo fluid properties keep the case small and stable. For air, edit `CFD/0/rho`, `CFD/constant/transportProperties`, and re-estimate inlet `U`.

## Layout

```
fluidized-bed/
├── README.md
├── Allrun.sh                 # mesh → DEM pack → coupled run
├── parDEMrun.sh
├── parCFDDEMrun.sh
├── CFD/
│   ├── 0/                    # initial fields (tracked in git)
│   ├── constant/             # couplingProperties, mesh after blockMesh
│   └── system/
└── DEM/
    ├── in.liggghts_init      # pack + settle → restart
    ├── in.liggghts_run       # coupled run (started by CFDEM)
    ├── dumpsToParaView       # dumps → particles.pvd (physical time)
    └── post/                 # dumps, VTK/PVD, restart (gitignored)
```

## Prerequisites (Mac + Docker)

1. Docker Desktop running  
2. Build **`cfdem:local`** once from the repo root:

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects
docker pull --platform linux/amd64 edoyango/cfdem:3.8.1
docker build --platform linux/amd64 -f Dockerfile.cfdem -t cfdem:local .
```

3. Start a container each session:

```bash
docker run -it --rm --platform linux/amd64 \
  -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \
  cfdem:local
```

See also `../LIGGGHTS_Mac_Docker_notes.md`.

## How to run

Inside **`cfdem:local`**:

```bash
cd /simulation/fluidized-bed
./Allrun.sh
```

This will:

1. Build the mesh with `blockMesh` (if needed)  
2. Pack/settle particles (`./parDEMrun.sh` → `DEM/post/restart/liggghts.restart`)  
3. Run coupled CFD–DEM (`./parCFDDEMrun.sh`)  
4. Abort if the DEM restart is missing  

Typical wall time on Mac (amd64 emulation): substantially longer than the old 1 s / 4000-particle case (5 s, 8000 particles, 0.01 s I/O).

### Step by step

```bash
cd /simulation/fluidized-bed
cd CFD && blockMesh && cd ..
./parDEMrun.sh          # packing (~80k DEM steps) — delete old restart first if re-packing
./parCFDDEMrun.sh       # 5 s fluidization
```

### Clean re-run

Must delete the old DEM restart so packing uses 8000 particles:

```bash
cd /simulation/fluidized-bed
rm -f DEM/post/restart/liggghts.restart
rm -rf DEM/post/dump*.liggghts_run DEM/post/particles_* DEM/post/particles.pvd
rm -rf CFD/processor* CFD/[1-9]* CFD/0.* CFD/postProcessing CFD/couplingFiles
./Allrun.sh
```

Remesh only if geometry changed: `rm -rf CFD/constant/polyMesh`.

## Post-processing in ParaView

Results live on the Mac under this folder (Docker bind mount). CFD writes are usually still **decomposed** under `CFD/processor*`.

### 1. Convert DEM dumps (physical time 0…1 s)

On the Mac (or in the container):

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects/fluidized-bed/DEM
./dumpsToParaView
```

Creates `post/particles_*.vtp` and **`post/particles.pvd`**.

Time mapping: `t = (DEM_step − step0) × 1e−5` so DEM dumps align with CFD at **0.01 s** spacing through **5 s**.

### 2. Open both datasets

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects/fluidized-bed/CFD
touch fluidizedBed.foam
open -a ParaView fluidizedBed.foam
# then File → Open → ../DEM/post/particles.pvd
```

| Source | Settings |
|--------|----------|
| `CFD/fluidizedBed.foam` | **Case Type → Decomposed Case** → Apply. Color by `voidfraction` or `U`. |
| `DEM/post/particles.pvd` | Apply. **Representation → Point Gaussian**, or **Glyph → Sphere** (scale by `radius`, Scale Factor = 1). |

Use one time slider: **0, 0.05, …, 1** for both.

**Do not** open CSV as a file series (that gives frame index 0,1,2,…) or legacy `.vtk` inside `.pvd` (broken pipeline / no eye icon). Use **`particles.pvd`** (XML `.vtp`).

### Optional: reconstruct CFD (fields only)

```bash
cd /simulation/fluidized-bed/CFD
reconstructPar -noLagrangian
```

(`-noLagrangian` is required — CFDEM `particleCloud` breaks plain `reconstructPar`.)

### Useful outputs

| Output | Location |
|--------|----------|
| CFD (decomposed) | `CFD/processor*/0.05` … `1` |
| DEM dumps | `DEM/post/dump*.liggghts_run` |
| DEM for ParaView | `DEM/post/particles.pvd` |
| Drag history | `DEM/post/forces.txt` |
| Logs | `log_run_liggghts_init_DEM`, `log_run_parallel_cfdemSolverPiso_fluidizedBed_CFDDEM` |

## Knobs

| Goal | Edit |
|------|------|
| Stronger / weaker fluidization | `CFD/0/U` (and `CFD/steps_0p1s`) |
| More / fewer particles | `particles_in_region` in `DEM/in.liggghts_init` |
| Geometry | `CFD/system/blockMeshDict` + DEM walls / insert region |
| Real air | `CFD/0/rho`, `transportProperties` `nu`, then adjust `U` |
| Longer run | `endTime` in `CFD/system/controlDict` |
| MPI ranks | `NR_PROCS` + `decomposeParDict` + DEM `processors` (must match) |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `blockMesh` / `cfdemSolverPiso` not found | Wrong image — use `cfdem:local` |
| No `liggghts.restart` / coupled run aborts | Check `log_run_liggghts_init_DEM`; keep `insert/pack` on **one line** |
| `alphaMin` / `velFieldName` undefined | Already set in `CFD/constant/couplingProperties` for this image |
| `reconstructPar` fails on `particleCloud` | Use `reconstructPar -noLagrangian` |
| ParaView DEM time is 0…19 | Open **`particles.pvd`**, not CSV series |
| `particles.pvd` has no eye / no filters | Must be XML `.vtp` collection; re-run `./dumpsToParaView` |

## Notes

- Soft Young’s modulus (5×10⁶ Pa) is for a fast demo, not real glass/steel.  
- Keep particle diameter smaller than ~3 CFD cells for the divided void-fraction model.  
- Runtime / post files are gitignored (see `.gitignore`); case inputs under `CFD/0`, `constant`, `system`, and `DEM/in.*` are what you commit.
