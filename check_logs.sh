#!/bin/bash

for date in {2..8}; do
  for hour in ${hours[@]}; do
    for N in {01..20}; do
      log_file=logs/CC/generate_ensemble_lag06/2021012${date}${hour}/wrf_ens_${N}.log
      echo "2021012${date}${hour}/wrf_ens_${N}"
      tail -n 1 ${log_file} >> ens_status.txt
    done
  done
done 
