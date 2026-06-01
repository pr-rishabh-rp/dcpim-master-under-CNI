#!/bin/bash
mapping=$1
workload=$2
pf_host=$3
pf_user=${4:-ubuntu}
pf_key=$5
pf_dir=${6:-~/dcPIM/implementation}

if [[ -z "$mapping" || -z "$workload" || -z "$pf_host" ]]; then
  echo "Usage: get_result_new.sh <vf_mapping.csv> <workload> <pf_host> [pf_user] [pf_key] [pf_dir]"
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
result_dir="$root_dir/../result/$(wc -l < "$mapping")"
mkdir -p "$result_dir"

scp_opts="-o StrictHostKeyChecking=no"
if [[ -n "$pf_key" ]]; then
  scp_opts="$scp_opts -i $pf_key"
fi

scp $scp_opts "${pf_user}@${pf_host}:${pf_dir}/result_${workload}_*.txt" "$result_dir/"

# usage: bash get_result_new.sh <vf_mapping.csv> <workload> 10.32.199.56 ubuntu /path/to/ssh_key /remote/dir
