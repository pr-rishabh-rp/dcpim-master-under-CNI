#!/bin/bash

export START_SSH_HOST=10.32.199.56
export START_SSH_USER=ubuntu
export START_SSH_KEY=~/.ssh/startpf
export START_SSH_DIR=~/dcpim-master-under-cni/dcPIM-master/implementation

./run_config_new.sh ../vf_mapping.csv
./run_exp_new.sh ../vf_mapping.csv websearch
./get_result_new.sh ../vf_mapping.csv websearch
python3 parse_result.py websearch ../vf_mapping.csv
