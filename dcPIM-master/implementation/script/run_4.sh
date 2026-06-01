#!/bin/bash

./run_config_new.sh ../vf_mapping.csv
./run_exp_new.sh ../vf_mapping.csv websearch
./get_result_new.sh ../vf_mapping.csv websearch 10.32.199.56 ubuntu /path/to/key /remote/dir
python3 parse_result.py 4 websearch
