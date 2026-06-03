#!/bin/bash
echo "CHECKPOINT: We are inside run_exp_new.sh"
mapping=$1
workload=$2

if [[ -z "$mapping" || -z "$workload" ]]; then
  echo "Usage: run_exp_new.sh <vf_mapping.csv> <workload>"
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
result_dir="$root_dir/../result/$(wc -l < "$mapping")"
echo "Making result directory..."
mkdir -p "$result_dir"

start_host="${START_SSH_HOST:-}"
start_user="${START_SSH_USER:-ubuntu}"
start_key="${START_SSH_KEY:-}"
start_port="${START_SSH_PORT:-22}"
start_dir="${START_SSH_DIR:-~/dcPIM/implementation}"
start_target=""
ssh_opts="-o StrictHostKeyChecking=no -p $start_port"
if [[ -n "$start_key" ]]; then
  ssh_opts="$ssh_opts -i $start_key"
fi
if [[ -n "$start_host" ]]; then
  start_target="${start_user}@${start_host}"
fi

senders=()
starters=()

# fills which ones are senders and starters
while IFS=, read -r id ip mac role pci lcores
do
  if [[ -z "$id" || "$id" == "id" || "$id" == \#* ]]; then
    continue
  fi
  if [[ -z "$pci" || -z "$lcores" ]]; then
    echo "Missing pci or lcores for id=$id"
    exit 1
  fi
  if [[ "$role" == "start" ]]; then
    starters+=("${id}|${pci}|${lcores}")
  else
    senders+=("${id}|${pci}|${lcores}")
  fi
done < "$mapping"

(cd "$root_dir" && sudo killall pim)
if [[ -n "$start_host" ]]; then
  echo "Going inside 10.32.199.56"; ssh $ssh_opts "$start_target" "cd $start_dir; sudo killall pim"
fi

for entry in "${senders[@]}"; do
  IFS="|" read -r id pci lcores <<< "$entry"
  bin="$root_dir/build/pim-$id"
  if [[ ! -x "$bin" ]]; then
    bin="$root_dir/build/pim"
  fi
  echo "CHECKPOINT: Running senders on VF$id"
  (cd "$root_dir" && sudo "$bin" -l "$lcores" -w "$pci" --file-prefix "vf$id" -- send CDF_${workload}.txt > "$result_dir/result_${workload}_${id}.txt") &
done

sleep 20

for entry in "${starters[@]}"; do
  IFS="|" read -r id pci lcores <<< "$entry"
  if [[ -n "$start_host" ]]; then
    echo "Once again, unto the breach PF$id..."; ssh $ssh_opts "$start_target" "cd $start_dir; if [ -x build/pim-$id ]; then bin=build/pim-$id; else bin=build/pim; fi; sudo ./\$bin -l $lcores -w $pci --file-prefix pf$id -- start CDF_${workload}.txt > result_${workload}_${id}.txt" &
  else
    bin="$root_dir/build/pim-$id"
    if [[ ! -x "$bin" ]]; then
      bin="$root_dir/build/pim"
    fi
    (cd "$root_dir" && sudo "$bin" -l "$lcores" -w "$pci" --file-prefix "pf$id" -- start CDF_${workload}.txt > "$result_dir/result_${workload}_${id}.txt") &
  fi
done

sleep 120

(cd "$root_dir" && sudo killall pim)
if [[ -n "$start_host" ]]; then
  ssh $ssh_opts "$start_target" "cd $start_dir; sudo killall pim"
fi
