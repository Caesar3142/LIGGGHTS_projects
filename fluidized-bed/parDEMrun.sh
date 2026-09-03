#!/bin/bash

#===================================================================#
# DEM init for fluidized-bed (packing + settle)
#===================================================================#

set -euo pipefail

if [ -z "${CFDEM_LIGGGHTS_EXEC:-}" ]; then
    echo "ERROR: CFDEM environment not loaded. Use image cfdem:local (see Dockerfile.cfdem)."
    exit 1
fi

echo "starting DEM run in parallel..."

casePath="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
logpath="$casePath"
headerText="run_liggghts_init_DEM"
logfileName="log_$headerText"
solverName="in.liggghts_init"
# Must match DEM/in.liggghts_run "processors" product for the coupled run (default 2*2*1=4)
nrProcs="${NR_PROCS:-4}"
machineFileName="none"
debugMode="off"

mkdir -p "$casePath/DEM/post/restart"

parDEMrun "$logpath" "$logfileName" "$casePath" "$headerText" "$solverName" "$nrProcs" "$machineFileName" "$debugMode"
