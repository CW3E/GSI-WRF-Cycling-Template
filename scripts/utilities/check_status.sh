#!/bin/bash

# take in workflow task parameters
cycle=$1
path=$2
cse=$3
flw=$4
tsk=$5

# grep the status from the workflow status log, searching for cycle and task
IFS=" " read -ra stat <<< `grep "${cycle}.*wrf_ens_00_${tsk}" ${path}/workflow_status/${cse}-${flw}_workflow_status.txt`

# determine if the task completed successfully
if [[ ${stat[0]} = ${cycle} && ${stat[3]} = "SUCCEEDED" ]]; then
  echo "wrf_ens_00_${tsk} is complete for cycle ${cycle}"
  exit 0
else
  echo "wrf_ens_00_${tsk} is not complete for cycle ${cycle}"
  exit 1
fi
