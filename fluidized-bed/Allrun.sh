#!/bin/bash

#===================================================================#
# Allrun: fluidized-bed CFD-DEM (CFDEM + LIGGGHTS)
# Based on CFDEMcoupling ErgunTestMPI tutorial, adapted for fluidization.
#===================================================================#

casePath="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# Build CFD mesh if missing
if [ -f "$casePath/CFD/constant/polyMesh/points" ]; then
    echo "mesh was built before - using old mesh"
else
    echo "mesh needs to be built"
    cd "$casePath/CFD" || exit 1
    blockMesh
fi

# DEM packing + settle → restart
if [ -f "$casePath/DEM/post/restart/liggghts.restart" ]; then
    echo "LIGGGHTS init was run before - using existing restart file"
else
    "$casePath/parDEMrun.sh"
fi

# Coupled CFD-DEM
. "$casePath/parCFDDEMrun.sh"
