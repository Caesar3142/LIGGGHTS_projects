#!/bin/bash

#===================================================================#
# Coupled CFD-DEM run for fluidized-bed (cfdemSolverPiso)
#===================================================================#

. ~/.bashrc
source "$CFDEM_SRC_DIR/lagrangian/cfdemParticle/etc/functions.sh"

casePath="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
logpath=$casePath
headerText="run_parallel_cfdemSolverPiso_fluidizedBed_CFDDEM"
logfileName="log_$headerText"
solverName="cfdemSolverPiso"
nrProcs="4"
machineFileName="none"
debugMode="off"
postproc="false"

# Parallel CFD-DEM
parCFDDEMrun "$logpath" "$logfileName" "$casePath" "$headerText" "$solverName" "$nrProcs" "$machineFileName" "$debugMode"

if [ "$postproc" == "true" ]; then
    cd "$casePath/DEM/post" || exit 1
    python -i "$CFDEM_LPP_DIR/lpp.py" dump*.liggghts_run

    cd "$casePath/CFD" || exit 1
    foamToVTK
    paraview
fi
