#!/bin/bash

# Reconstruct CFD fields, then convert DEM dumps for ParaView.

set -euo pipefail

casePath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cfdPath="$casePath/CFD"
demPath="$casePath/DEM"

if ! command -v reconstructPar >/dev/null 2>&1; then
    echo "ERROR: reconstructPar not found. Run this inside the cfdem:local container."
    exit 1
fi

if ! compgen -G "$cfdPath/processor*" >/dev/null; then
    echo "ERROR: no CFD/processor* directories found. Run the coupled case first."
    exit 1
fi

if ! compgen -G "$demPath/post/dump*.liggghts_run" >/dev/null; then
    echo "ERROR: no DEM/post/dump*.liggghts_run files found."
    exit 1
fi

echo "Reconstructing CFD fields..."
(
    cd "$cfdPath"
    # CFDEM particleCloud data is incompatible with plain reconstructPar.
    reconstructPar -noLagrangian
    touch fluidizedBed.foam
)

echo "Converting DEM dumps for ParaView..."
"$demPath/dumpsToParaView" "$@"

echo "Post-processing complete:"
echo "  CFD: $cfdPath/fluidizedBed.foam"
echo "  DEM: $demPath/post/particles.pvd"
