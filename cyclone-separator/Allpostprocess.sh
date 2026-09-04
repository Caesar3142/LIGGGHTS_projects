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
print(round(int("$latestDumpStep") * 2e-6, 6))
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
    # Re-run is safe: already-reconstructed times are skipped/overwritten.
    reconstructPar -noLagrangian
    touch cycloneSeparator.foam
)

echo "Converting DEM dumps for ParaView (rewrites particles.pvd)..."
# step0=0 so physical time = DEM_step * dt matches CFD absolute time
# after cold start and after ./parCFDDEMcontinue.sh.
"$demPath/dumpsToParaView" --step0 0 --dt 2e-6 "$@"

echo "Post-processing complete:"
echo "  CFD: $cfdPath/cycloneSeparator.foam"
echo "  DEM: $demPath/post/particles.pvd"
echo ""
echo "In ParaView: File -> Reload Files (or close/reopen both sources)"
echo "so the time slider picks up times after a continue."
