#!/bin/bash

# Reconstruct CFD fields, then convert ALL DEM dumps for ParaView.
# Re-run this after ./parCFDDEMcontinue.sh so ParaView sees new times.

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

latestProc="$(ls -1 "$cfdPath/processor0" | awk '/^[0-9]/ && $0 != "0" {print}' | sort -n | tail -1)"
latestDumpStep="$(ls -1 "$demPath/post"/dump*.liggghts_run | sed 's|.*/dump||;s|\.liggghts_run||' | sort -n | tail -1)"
latestDumpTime="$(python3 - <<PY
print(round(int("$latestDumpStep") * 1e-6, 6))
PY
)"

echo "Latest CFD processor time: ${latestProc:-none}"
echo "Latest DEM dump: step $latestDumpStep -> t=${latestDumpTime} s"

if python3 - <<PY
import sys
cfd = float("${latestProc:-0}")
dem = float("${latestDumpTime:-0}")
sys.exit(0 if abs(cfd - dem) <= 0.005 + 1e-12 else 1)
PY
then
    :
else
    echo "WARNING: CFD time (${latestProc}) and DEM dump time (${latestDumpTime}) differ."
    echo "         particles.pvd follows DEM dumps. A previous continue likely"
    echo "         resumed CFD ahead of DEM. Fix by continuing from the synced time:"
    echo "           ./parCFDDEMcontinue.sh"
fi

echo "Reconstructing CFD fields..."
(
    cd "$cfdPath"
    # CFDEM particleCloud data is incompatible with plain reconstructPar.
    # OpenFOAM-5 reconstructPar is serial; speed it up by splitting times
    # across several independent reconstructPar processes.
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
        echo "ERROR: $fails reconstructPar job(s) failed; see CFD/../log_reconstructPar_*"
        exit 1
    fi
    touch cycloneSeparator.foam
)

echo "Converting DEM dumps for ParaView (rewrites particles.pvd)..."
# step0=0 so physical time = DEM_step * dt matches CFD absolute time
# after cold start and after ./parCFDDEMcontinue.sh.
"$demPath/dumpsToParaView" --step0 0 --dt 1e-6 "$@"

echo "Post-processing complete:"
echo "  CFD: $cfdPath/cycloneSeparator.foam"
echo "  DEM: $demPath/post/particles.pvd"
echo ""
echo "In ParaView: File -> Reload Files (or close/reopen both sources)"
echo "so the time slider picks up times after a continue."
