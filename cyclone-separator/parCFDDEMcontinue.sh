#!/bin/bash

#===================================================================#
# Continue the cyclone CFD-DEM run from the last written time
# (parallel, without re-decomposing processor* directories).
#
# Usage (inside cfdem:local):
#   cd /simulation/cyclone-separator
#   ./parCFDDEMcontinue.sh              # resume to controlDict endTime
#   END_TIME=2.0 ./parCFDDEMcontinue.sh # optional new end time
#===================================================================#

set -euo pipefail

if ! command -v cfdemSolverPiso >/dev/null 2>&1; then
    echo "ERROR: cfdemSolverPiso not found. Use image cfdem:local (see Dockerfile.cfdem)."
    exit 1
fi

casePath="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cfdPath="$casePath/CFD"
demPath="$casePath/DEM"
restartDir="$demPath/post/restart"
nrProcs="${NR_PROCS:-8}"
demDt=0.000001
feedTotal=250
feedRate=500

controlDict="$cfdPath/system/controlDict"
couplingProps="$cfdPath/constant/couplingProperties"
continueInput="$demPath/in.liggghts_continue"
continueInputRun="$demPath/in.liggghts_continue.active"
continueRestart="$restartDir/liggghts.continue"

mkdir -p "$restartDir" "$cfdPath/couplingFiles"
touch "$cfdPath/couplingFiles/.keep"

if ! compgen -G "$cfdPath/processor*" >/dev/null; then
    echo "ERROR: no CFD/processor* directories found. Start with ./Allrun.sh first."
    exit 1
fi

# Latest CFD write time across processor directories.
latestTime="$(
python3 - <<'PY' "$cfdPath" "$nrProcs"
import os, sys, re
cfd, nprocs = sys.argv[1], int(sys.argv[2])
times = []
pat = re.compile(r"^[0-9]+(\.[0-9]+)?$")
for p in range(nprocs):
    d = os.path.join(cfd, f"processor{p}")
    if not os.path.isdir(d):
        sys.exit(f"missing {d}")
    for name in os.listdir(d):
        if pat.match(name) and name != "0":
            times.append(float(name))
if not times:
    sys.exit("no written time directories found under CFD/processor*")
# Require the time to exist on every rank.
from collections import Counter
counts = Counter(times)
common = [t for t, c in counts.items() if c == nprocs]
if not common:
    sys.exit("no common written time found on all processors")
print(max(common))
PY
)"

echo "Latest CFD time: $latestTime"

# Matching DEM step for dump/restart naming.
demStep="$(
python3 - <<'PY' "$latestTime" "$demDt"
import sys
t = float(sys.argv[1]); dt = float(sys.argv[2])
print(int(round(t / dt)))
PY
)"

dumpFile="$demPath/post/dump${demStep}.liggghts_run"
echo "Matching DEM step: $demStep"

pick_restart_source() {
    local candidates=()
    # Preferred: exact timestep restart from LIGGGHTS `restart` command.
    if [ -f "$restartDir/liggghts.restart.${demStep}" ]; then
        candidates+=("$restartDir/liggghts.restart.${demStep}")
    fi
    # CFDEM writeLiggghts naming variants.
    if compgen -G "$restartDir/liggghts.restartCFDEM_${latestTime}" >/dev/null; then
        candidates+=("$restartDir/liggghts.restartCFDEM_${latestTime}")
    fi
    if [ -f "$restartDir/liggghts.restartCFDEM" ]; then
        candidates+=("$restartDir/liggghts.restartCFDEM")
    fi
    # Any timestamped restartCFDEM_* — take numerically latest.
    if compgen -G "$restartDir/liggghts.restartCFDEM_*" >/dev/null; then
        local latest
        latest="$(ls -1 "$restartDir"/liggghts.restartCFDEM_* | sort -t_ -k2 -n | tail -1)"
        candidates+=("$latest")
    fi
    # Any liggghts.restart.* — take highest step <= demStep.
    if compgen -G "$restartDir/liggghts.restart.*" >/dev/null; then
        local best=""
        local bestStep=-1
        local f step
        for f in "$restartDir"/liggghts.restart.*; do
            step="${f##*.}"
            if [[ "$step" =~ ^[0-9]+$ ]] && [ "$step" -le "$demStep" ] && [ "$step" -gt "$bestStep" ]; then
                best="$f"
                bestStep="$step"
            fi
        done
        if [ -n "$best" ]; then
            candidates+=("$best")
        fi
    fi

    if [ "${#candidates[@]}" -gt 0 ]; then
        printf '%s\n' "${candidates[0]}"
        return 0
    fi
    return 1
}

build_restart_from_dump() {
    local dump="$1"
    local outRestart="$2"
    local tmpDir dataFile makeInput nAtoms remain

    if [ ! -f "$dump" ]; then
        echo "ERROR: no DEM dump at $dump and no binary restart found."
        echo "Cannot continue particle state. Re-run with the updated in.liggghts_run"
        echo "(which writes DEM/post/restart/liggghts.restart.*) or provide a restart file."
        exit 1
    fi

    echo "No DEM binary restart found — building one from $dump"

    tmpDir="$(mktemp -d "$demPath/post/tmp_continue.XXXXXX")"
    dataFile="$tmpDir/particles.data"
    makeInput="$tmpDir/make_restart.liggghts"

    nAtoms="$(python3 "$demPath/dump_to_data.py" "$dump" "$dataFile")"

    remain=$(( feedTotal - nAtoms ))
    if [ "$remain" -lt 0 ]; then
        remain=0
    fi

    cat > "$makeInput" <<EOF
echo            both
log             $tmpDir/log.make_restart
atom_style      granular
atom_modify     map array
atom_modify     sort 0 0.0
communicate     single vel yes
boundary        f f f
newton          off
units           si
read_data       $dataFile
neighbor        0.0003 bin
neigh_modify    delay 0
fix         m1 all property/global youngsModulus peratomtype 1.e7
fix         m2 all property/global poissonsRatio peratomtype 0.25
fix         m3 all property/global coefficientRestitution peratomtypepair 1 0.45
fix         m4 all property/global coefficientFriction peratomtypepair 1 0.40
pair_style  gran model hertz tangential history
pair_coeff  * *
timestep    $demDt
reset_timestep $demStep
write_restart   $outRestart
EOF

    if [ -z "${CFDEM_LIGGGHTS_EXEC:-}" ] || [ ! -x "${CFDEM_LIGGGHTS_EXEC}" ]; then
        echo "ERROR: CFDEM_LIGGGHTS_EXEC is not set/executable; cannot build restart from dump."
        exit 1
    fi

    "${CFDEM_LIGGGHTS_EXEC}" -in "$makeInput"
    rm -rf "$tmpDir"

    # Rewrite remaining particle budget in the active continue DEM input.
    sed -i "s/nparticles [0-9][0-9]*/nparticles ${remain}/" "$continueInputRun"
    echo "Built DEM restart with $nAtoms atoms; remaining insert budget = $remain"
}

cp -f "$continueInput" "$continueInputRun"

srcRestart=""
if srcRestart="$(pick_restart_source)"; then
    echo "Using DEM restart: $srcRestart"
    cp -f "$srcRestart" "$continueRestart"
    # Estimate remaining insert budget from dump atom count when available.
    if [ -f "$dumpFile" ]; then
        nAtoms="$(awk '/ITEM: NUMBER OF ATOMS/{getline; print; exit}' "$dumpFile")"
        remain=$(( feedTotal - nAtoms ))
        if [ "$remain" -lt 0 ]; then remain=0; fi
        sed -i "s/nparticles [0-9][0-9]*/nparticles ${remain}/" "$continueInputRun"
        echo "Atoms in matching dump: $nAtoms; remaining insert budget = $remain"
    fi
else
    build_restart_from_dump "$dumpFile" "$continueRestart"
fi

# Backup and retarget OpenFOAM / CFDEM inputs for continue.
controlBak="$controlDict.continuebak"
couplingBak="$couplingProps.continuebak"
cp -f "$controlDict" "$controlBak"
cp -f "$couplingProps" "$couplingBak"

cleanup() {
    if [ -f "$controlBak" ]; then mv -f "$controlBak" "$controlDict"; fi
    if [ -f "$couplingBak" ]; then mv -f "$couplingBak" "$couplingProps"; fi
    rm -f "$continueInputRun"
}
trap cleanup EXIT

python3 - <<'PY' "$controlDict" "$latestTime" "${END_TIME:-}"
import re, sys
path, latest, end = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
text = re.sub(r"(?m)^startFrom\s+\S+;", "startFrom       latestTime;", text)
text = re.sub(r"(?m)^startTime\s+\S+;", f"startTime       {latest};", text)
if end:
    text = re.sub(r"(?m)^endTime\s+\S+;", f"endTime         {end};", text)
open(path, "w").write(text)
print(f"controlDict: startFrom latestTime (from {latest})" + (f", endTime {end}" if end else ""))
PY

python3 - <<'PY' "$couplingProps"
import re, sys
path = sys.argv[1]
text = open(path).read()
text = re.sub(
    r'liggghtsPath\s+"[^"]+";',
    'liggghtsPath "../DEM/in.liggghts_continue.active";',
    text,
)
open(path, "w").write(text)
print("couplingProperties: liggghtsPath -> in.liggghts_continue.active")
PY

logpath=$casePath
headerText="continue_parallel_cfdemSolverPiso_cycloneSeparator_CFDDEM"
logfileName="log_$headerText"
solverName="cfdemSolverPiso"
machineFileName="none"
debugMode="off"
# args: reconstructCase decomposeCase
# Do NOT re-decompose — that would wipe processor time directories.
reconstructCase="false"
decomposeCase="false"

echo "Continuing parallel CFD-DEM from t=$latestTime (NR_PROCS=$nrProcs)..."
parCFDDEMrun "$logpath" "$logfileName" "$casePath" "$headerText" "$solverName" \
    "$nrProcs" "$machineFileName" "$debugMode" "$reconstructCase" "$decomposeCase"

if [ -f "$casePath/$logfileName" ] &&
   grep -Eq "FOAM FATAL|ERROR on proc|MPI_ABORT" "$casePath/$logfileName"; then
    echo "ERROR: continued solver failed; see $casePath/$logfileName"
    exit 1
fi

echo "Continue finished. Log: $casePath/$logfileName"
