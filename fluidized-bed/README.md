# fluidized-bed

CFDEM®coupling case: **gas–solid fluidized bed** (OpenFOAM `cfdemSolverPiso` ↔ LIGGGHTS).

Adapted from the public CFDEM tutorial `cfdemSolverPiso/ErgunTestMPI`, with a taller freeboard and inlet velocity above minimum fluidization.

**Requires `cfdem:local`.** Do not use `liggghts:local` (DEM-only — no `blockMesh` / `cfdemSolverPiso`).

## Case overview

| Item | Value |
|------|--------|
| Solver | `cfdemSolverPiso` (4-way CFD–DEM) |
| Column | Cylinder, D ≈ **27.6 mm**, H = **150 mm** |
| Particles | ~**4000** spheres, d = **1 mm**, ρ = **2000 kg/m³** |
| Contact | Hertz + tangential history (soft demo solids, E = 5×10⁶ Pa) |
| Fluid (demo) | ρ = 10 kg/m³, ν = 1.5×10⁻⁴ m²/s (same as ErgunTestMPI — not real air) |
| Inlet U | Ramps **0.02 → 0.15 m/s** (z+) over 0.2 s |
| CFD Δt | 5×10⁻⁴ s |
| DEM Δt | 1×10⁻⁵ s |
| Coupling | every **100** DEM steps (`couple_every 100`); CFD `couplingInterval 50` |
| End time | **1.0 s** |
| MPI | **4** ranks (`processors 2 2 1` in DEM; `decomposeParDict` = 4) |

Demo fluid properties keep the case small and stable. For air, change `CFD/0/rho`, `CFD/constant/transportProperties`, and re-estimate \(U_{mf}\) / inlet `U`.

## Layout

```
fluidized-bed/
├── README.md
├── Allrun.sh                 # mesh → DEM pack → coupled run
├── parDEMrun.sh              # LIGGGHTS packing (in.liggghts_init)
├── parCFDDEMrun.sh           # cfdemSolverPiso + LIGGGHTS (in.liggghts_run)
├── CFD/
│   ├── 0/                    # U, p, voidfraction, rho, Us, …
│   ├── constant/
│   │   ├── couplingProperties   # drag, void fraction, MPI path to DEM
│   │   ├── liggghtsCommands
│   │   ├── transportProperties
│   │   └── …
│   ├── system/
│   │   ├── blockMeshDict
│   │   ├── controlDict
│   │   └── …
│   └── couplingFiles/        # created at runtime
└── DEM/
    ├── in.liggghts_init      # pack + settle → restart
    ├── in.liggghts_run       # coupled run (started by CFDEM)
    └── post/                 # dumps, forces, restart
```

## Prerequisites (Mac + Docker)

1. Docker Desktop running  
2. Build the CFDEM image **once** from the repo root:

```bash
cd ~/Documents_Local/GitHub/LIGGGHTS_projects
docker pull --platform linux/amd64 edoyango/cfdem:3.8.1
docker build --platform linux/amd64 -f Dockerfile.cfdem -t cfdem:local .
```

3. Start a container (every session):

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

What `Allrun.sh` does:

1. `blockMesh` (if `CFD/constant/polyMesh` is missing)  
2. DEM packing via `./parDEMrun.sh` → `DEM/post/restart/liggghts.restart`  
3. Coupled CFD–DEM via `./parCFDDEMrun.sh` (`decomposePar` + `cfdemSolverPiso`)  
4. Stops with an error if the DEM restart was not created  

### Step by step

```bash
cd /simulation/fluidized-bed
cd CFD && blockMesh && cd ..
./parDEMrun.sh          # ~50k DEM settle steps → liggghts.restart
./parCFDDEMrun.sh       # 1 s coupled fluidization
```

Optional: `NR_PROCS=4 ./Allrun.sh` — must match `processors` in `DEM/in.liggghts_run` and `CFD/system/decomposeParDict`.

### Clean re-run

```bash
cd /simulation/fluidized-bed
rm -f DEM/post/restart/liggghts.restart
rm -rf CFD/processor* CFD/[1-9]* CFD/0.* CFD/probes
./Allrun.sh
```

Remesh only if the column geometry changed:

```bash
rm -rf CFD/constant/polyMesh
```

## Post-processing

On the Mac (results are already in the mounted folder):

| Output | Location |
|--------|----------|
| CFD fields | `CFD/0.05`, `CFD/0.1`, … (write every 0.05 s) |
| DEM dumps | `DEM/post/dump*.liggghts_run` |
| Drag history | `DEM/post/forces.txt` |
| DEM restart (end) | `DEM/post/restart/liggghts.restartCFDEM_*` |
| Run logs | `log_run_liggghts_init_DEM`, `log_run_parallel_cfdemSolverPiso_fluidizedBed_CFDDEM` |

CFD in ParaView:

```bash
# inside container, or use Mac ParaView on foam files
cd CFD
touch fluidizedBed.foam
# open fluidizedBed.foam in ParaView
```

Or: `foamToVTK` then open the VTK series.

DEM particles: convert LIGGGHTS dumps with your usual dump→CSV/VTK workflow (similar to `dumpsToParaView` in the DEM-only cases).

## Knobs to change

| Goal | Edit |
|------|------|
| Stronger / weaker fluidization | `CFD/0/U` inlet table (and `CFD/steps_0p1s`) |
| More / fewer particles | `particles_in_region` in `DEM/in.liggghts_init` |
| Taller / shorter bed | `blockMeshDict` height + DEM `zplane` / insert region |
| Real air | `CFD/0/rho`, `transportProperties` `nu`, then adjust `U` |
| Longer run | `endTime` in `CFD/system/controlDict` |
| MPI ranks | `NR_PROCS` / `par*.sh` + `decomposeParDict` + DEM `processors` |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `blockMesh: command not found` | Wrong image — exit and start `cfdem:local` |
| `Cannot open restart file …/liggghts.restart` | DEM init failed; check `log_run_liggghts_init_DEM`, then re-run `./parDEMrun.sh` |
| `insert/pack … unknown keyword` | Keep LIGGGHTS commands on **one line** (no `\` continuations) |
| `alphaMin is undefined` in `dividedProps` | Set `alphaMin 0.1;` in `CFD/constant/couplingProperties` |
| `velFieldName is undefined` in `implicitCoupleProps` | Set `velFieldName`, `granVelFieldName`, `voidfractionFieldName` (already filled for `cfdem:local`) |

The `cfdem:local` image ships an older CFDEM build that **requires** those dictionary entries even when newer tutorials leave them empty.

## Notes

- Keep particle diameter **smaller than ~3 CFD cells** for the divided void-fraction model.
- Soft Young’s modulus (5×10⁶ Pa) is for a fast demo, not real glass/steel.
- Source template: [CFDEMcoupling-PUBLIC `ErgunTestMPI`](https://github.com/CFDEMproject/CFDEMcoupling-PUBLIC/tree/master/tutorials/cfdemSolverPiso/ErgunTestMPI).
