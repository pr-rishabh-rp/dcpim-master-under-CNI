#!/bin/bash

# TODO: Replace 16 with your host/VF count, or use a custom wrapper script.
./run_config.sh 16
./run_exp.sh websearch 16
./get_result.sh 16
python3 parse_result.py 16 websearch
