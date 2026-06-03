#!/bin/bash
mapping=$1

if [[ -z "$mapping" ]]; then
  echo "Usage: run_config_new.sh <vf_mapping.csv>"
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"

start_host="${START_SSH_HOST:-}"
start_user="${START_SSH_USER:-ubuntu}"
start_key="${START_SSH_KEY:-}"
start_port="${START_SSH_PORT:-22}"
start_dir="${START_SSH_DIR:-~/dcpim-master-under-cni/dcPIM-master/implementation}"
start_target=""
ssh_opts="-o StrictHostKeyChecking=no -p $start_port"
if [[ -n "$start_key" ]]; then
  ssh_opts="$ssh_opts -i $start_key"
fi
if [[ -n "$start_host" ]]; then
  start_target="${start_user}@${start_host}"
fi

mapping_abs="$(cd "$(dirname "$mapping")" && pwd)/$(basename "$mapping")"
if [[ -n "$start_host" ]]; then
  scp $ssh_opts "$mapping_abs" "${start_target}:${start_dir}/vf_mapping.csv"
fi

while IFS=, read -r id ip mac role pci lcores
do
  if [[ -z "$id" || "$id" == "id" || "$id" == \#* ]]; then
    continue
  fi
  echo "Building config for id=$id ip=$ip"
  if [[ "$role" == "start" && -n "$start_host" ]]; then
    echo "CHECKPOINT: Attempting to ssh into 10.32.199.56"; ssh -n $ssh_opts "$start_target" "cd $start_dir; bash ./run.sh --mapping vf_mapping.csv --self-id $id"
  else
    echo "CHECKPOINT: Running run.sh locally for VF$id."; (cd "$root_dir" && bash ./run.sh --mapping vf_mapping.csv --self-id "$id")
    if [[ -f "$root_dir/src/config2.c" ]]; then
      cp "$root_dir/src/config2.c" "$root_dir/src/config2_$id.c"
    fi
    if [[ -f "$root_dir/build/pim" ]]; then
      echo "Copying stuff for VFs into build according to ID:$id."; cp "$root_dir/build/pim" "$root_dir/build/pim-$id"
    fi
  fi
done < "$mapping"
