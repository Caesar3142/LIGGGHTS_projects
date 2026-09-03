#!/bin/bash

#===================================================================#
# DEM init for fluidized-bed (packing + settle)
#===================================================================#

. ~/.bashrc
source "$CFDEM_SRC_DIR/lagrangian/cfdemParticle/etc/functions.sh"

echo "starting DEM run in parallel..."

casePath="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
logpath="$casePath"
headerText="run_liggghts_init_DEM"
logfileName="log_$headerText"
solverName="in.liggghts_init"
nrProcs=4
machineFileName="none"
debugMode="off"

mkdir -p "$casePath/DEM/post/restart"

parDEMrun "$logpath" "$logfileName" "$casePath" "$headerText" "$solverName" "$nrProcs" "$machineFileName" "$debugMode"
