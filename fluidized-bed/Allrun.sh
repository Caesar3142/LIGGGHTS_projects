#!/bin/bash

#===================================================================#
# Allrun: fluidized-bed CFD-DEM (CFDEM + LIGGGHTS)
# Based on CFDEMcoupling ErgunTestMPI tutorial, adapted for fluidization.
#
# Requires the cfdem:local Docker image (see ../Dockerfile.cfdem), NOT liggghts:local.
#===================================================================#

set -euo pipefail

casePath="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: '$1' not found."
        echo "This case needs OpenFOAM + CFDEMcoupling."
        echo "Exit this container and start:"
        echo "  docker run -it --rm --platform linux/amd64 \\"
        echo "    -v ~/Documents_Local/GitHub/LIGGGHTS_projects:/simulation \\"
        echo "    cfdem:local"
        echo "Build once with: docker build --platform linux/amd64 -f Dockerfile.cfdem -t cfdem:local ."
        exit 1
    fi
}

require_cmd blockMesh
require_cmd cfdemSolverPiso
require_cmd parDEMrun
require_cmd parCFDDEMrun

if [ -z "${CFDEM_LIGGGHTS_EXEC:-}" ] || [ ! -x "${CFDEM_LIGGGHTS_EXEC}" ]; then
    echo "ERROR: CFDEM_LIGGGHTS_EXEC is not set or not executable."
    echo "Use the cfdem:local image (Dockerfile.cfdem), not liggghts:local."
    exit 1
fi

mkdir -p "$casePath/DEM/post/restart" "$casePath/CFD/couplingFiles"
# parCFDDEMrun does: rm couplingFiles/*
touch "$casePath/CFD/couplingFiles/.keep"

# Build CFD mesh if missing
if [ -f "$casePath/CFD/constant/polyMesh/points" ]; then
    echo "mesh was built before - using old mesh"
else
    echo "mesh needs to be built"
    cd "$casePath/CFD"
    blockMesh
fi

# DEM packing + settle → restart
restartFile="$casePath/DEM/post/restart/liggghts.restart"
if [ -f "$restartFile" ]; then
    echo "LIGGGHTS init was run before - using existing restart file"
else
    "$casePath/parDEMrun.sh"
fi

if [ ! -f "$restartFile" ]; then
    echo "ERROR: DEM init did not create $restartFile"
    echo "Check log_run_liggghts_init_DEM — do not start CFD-DEM without a restart."
    exit 1
fi

# Coupled CFD-DEM
"$casePath/parCFDDEMrun.sh"
