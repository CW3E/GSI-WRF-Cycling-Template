#!/bin/bash

cycle=$1
path=$2
cse=$3
flw=$4

IFS=" " read -ra stat <<< `grep wrf_ens_00_cyc ${path}/workflow_status/${cse}-${flw}_workflow_status.txt | tail -n 1`

if [[ ${stat[0]} = ${cycle} && ${stat[3]} = "SUCCEEDED" ]]; then
  echo "wrf_ens_00_cyc is complete for cycle ${cycle}"
  exit 0
else
  echo "wrf_ens_00_cyc is not complete for cycle ${cycle}"
  exit 1
fi
