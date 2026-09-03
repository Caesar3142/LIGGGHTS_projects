

declare -x LOGNAME="EngineerDo"
declare -x LANG="de_DE.UTF-8"
declare -x HOME="/home/vc-a/dem"
declare -x HISTSIZE="1000"
declare -x HISTCONTROL="ignoredups"
declare -x SHELL="/bin/bash"
declare -x USER="dem"
declare -x MODULESHOME="/usr/share/Modules"


#- define variables
casePath="$(dirname "$(readlink -f ${BASH_SOURCE[0]})")"

cp S_con.stl $casePath/CFD 


cd $casePath



$casePath/parCFDDEMrun.sh


