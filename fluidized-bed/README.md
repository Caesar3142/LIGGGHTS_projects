# fluidized-bed

CFDEM®coupling case: **gas–solid fluidized bed** (OpenFOAM `cfdemSolverPiso` ↔ LIGGGHTS).

Adapted from the public CFDEM tutorial `cfdemSolverPiso/ErgunTestMPI`, with a taller freeboard and inlet velocity above minimum fluidization.

## Case overview

| Item | Value |
|------|--------|
| Solver | `cfdemSolverPiso` (4-way CFD–DEM) |
| Column | Cylinder, D ≈ **27.6 mm**, H = **150 mm** |
| Particles | ~**4000** spheres, d = **1 mm**, ρ = **2000 kg/m³** |
| Contact | Hertz + tangential history (soft demo solids, E = 5×10⁶ Pa) |
| Fluid (demo) | ρ = 10 kg/m³, ν = 1.5×10⁻⁴ m²/s (same as ErgunTestMPI — not real air) |
| Inlet U | Ramps **0.02 → 0.15 m/s** (z-direction) over 0.2 s |
| CFD Δt | 5×10⁻⁴ s |
| DEM Δt | 1×10⁻⁵ s |
| Coupling | every **100** DEM steps (`couple_every 100`) |
| End time | **1.0 s** |
| MPI | **4** ranks (2×2×1) |

Demo fluid properties keep the case small and stable. For air, change `CFD/0/rho`, `CFD/constant/transportProperties`, and re-estimate \(U_{mf}\) / inlet `U`.

## Layout

```
fluidized-bed/
├── README.md
├── Allrun.sh                 # mesh → DEM pack → coupled run
├── parDEMrun.sh              # LIGGGHTS packing (in.liggghts_init)
├── parCFDDEMrun.sh           # cfdemSolverPiso + LIGGGHTS (in.liggghts_run)
├── CFD/
│   ├── 0/                    # U, p, voidfraction, rho, …
│   ├── constant/
│   │   ├── couplingProperties
│   │   ├── liggghtsCommands
│   │   ├── transportProperties
│   │   └── …
│   └── system/
│       ├── blockMeshDict
│       ├── controlDict
│       └── …
└── DEM/
    ├── in.liggghts_init      # pack + settle → restart
    ├── in.liggghts_run       # coupled run (started by CFDEM)
    └── post/                 # dumps, forces, restart (created at runtime)
```

## Prerequisites

1. Working **CFDEM®coupling** install (OpenFOAM + LIGGGHTS as shared lib + CFDEMcoupling).
2. Environment loaded (`CFDEM_SRC_DIR`, `cfdemSolverPiso` on `PATH`).
3. This case will **not** run in the current DEM-only `liggghts:local` Docker image.

See CFDEM docs: https://www.cfdem.com/media/CFDEM/docu/CFDEMcoupling_Manual.html

## How to run

```bash
cd /path/to/LIGGGHTS_projects/fluidized-bed
./Allrun.sh
```

Or step by step:

```bash
cd CFD && blockMesh && cd ..
./parDEMrun.sh          # creates DEM/post/restart/liggghts.restart
./parCFDDEMrun.sh       # coupled fluidization
```

Post-process:

- CFD: `cd CFD && paraFoam` (or `foamToVTK`)
- DEM: dumps under `DEM/post/dump*.liggghts_run`
- Drag history: `DEM/post/forces.txt`

## Knobs to change

| Goal | Edit |
|------|------|
| Stronger / weaker fluidization | `CFD/0/U` inlet table (and `CFD/steps_0p1s`) |
| More / fewer particles | `particles_in_region` in `DEM/in.liggghts_init` |
| Taller / shorter bed | `blockMeshDict` height + DEM `zplane` / insert region |
| Real air | `rho`, `nu`, then lower `U` toward measured \(U_{mf}\) |
| Longer run | `endTime` in `CFD/system/controlDict` |
| MPI ranks | `nrProcs` in `par*.sh` + `decomposeParDict` + DEM `processors` |

## Notes

- Keep particle diameter **smaller than ~3 CFD cells** for the divided void-fraction model.
- Delete `DEM/post/restart/liggghts.restart` (and remesh if geometry changed) before a clean re-init.
- Source template: [CFDEMcoupling-PUBLIC `ErgunTestMPI`](https://github.com/CFDEMproject/CFDEMcoupling-PUBLIC/tree/master/tutorials/cfdemSolverPiso/ErgunTestMPI).
