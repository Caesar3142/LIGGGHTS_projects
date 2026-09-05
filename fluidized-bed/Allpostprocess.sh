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
    # OpenFOAM-5 reconstructPar is serial; split times across parallel jobs.
    nJobs="${RECONSTRUCT_JOBS:-${NR_PROCS:-8}}"
    mapfile -t times < <(
        ls -1 processor0 |
        awk '/^[0-9]+([.][0-9]+)?$/ && $0 != "0" {print}' |
        sort -n
    )
    nTimes="${#times[@]}"
    if [ "$nTimes" -eq 0 ]; then
        echo "ERROR: no result times found under processor0/"
        exit 1
    fi
    if [ "$nJobs" -gt "$nTimes" ]; then
        nJobs="$nTimes"
    fi
    echo "  $nTimes times -> $nJobs parallel reconstructPar jobs (-noLagrangian -newTimes)"

    pids=()
    fails=0
    for ((i = 0; i < nJobs; i++)); do
        start=$((i * nTimes / nJobs))
        end=$(((i + 1) * nTimes / nJobs))
        if [ "$start" -ge "$end" ]; then
            continue
        fi
        t0="${times[$start]}"
        t1="${times[$((end - 1))]}"
        log="../log_reconstructPar_${i}"
        (
            echo "  job $i: times ${t0}:${t1} (${start}..$((end - 1)))"
            reconstructPar -noLagrangian -newTimes -time "${t0}:${t1}" >"$log" 2>&1
        ) &
        pids+=("$!")
    done

    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            fails=$((fails + 1))
        fi
    done
    if [ "$fails" -ne 0 ]; then
        echo "ERROR: $fails reconstructPar job(s) failed; see log_reconstructPar_*"
        exit 1
    fi
    touch fluidizedBed.foam
)

echo "Converting DEM dumps for ParaView..."
"$demPath/dumpsToParaView" "$@"

echo "Post-processing complete:"
echo "  CFD: $cfdPath/fluidizedBed.foam"
echo "  DEM: $demPath/post/particles.pvd"
