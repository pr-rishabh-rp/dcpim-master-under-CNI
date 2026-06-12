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
result_dir="$root_dir/result/$(wc -l < "$mapping")"
echo "Making result directory..."
mkdir -p "$result_dir"
echo "DEBUG result_dir: $result_dir"

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

echo "DEBUG senders: ${senders[@]}"
echo "DEBUG starters: ${starters[@]}"

(cd "$root_dir" && sudo killall -r '^pim')
if [[ -n "$start_host" ]]; then
  echo "Going inside 10.32.199.56"; ssh -n $ssh_opts "$start_target" "cd $start_dir; sudo killall -r '^pim'"
fi

# Senders used to be before but due to the host PF link being down due to the remote PF link being down (control is in the hands of DPDK), nfp_net_reconfig() was failing with 80000000.

for entry in "${starters[@]}"; do
  IFS="|" read -r id pci lcores <<< "$entry"
  if [[ -n "$start_host" ]]; then
    echo "Once again, unto the breach PF$id..."; ssh $ssh_opts "$start_target" "cd $start_dir; if [ -x build/pim-$id ]; then bin=$start_dir/build/pim-$id; else bin=$start_dir/build/pim; fi; sudo \$bin -l $lcores -w $pci --file-prefix pf$id -- start CDF_${workload}.txt $id > result_${workload}_${id}.txt" &
  else
    bin="$root_dir/build/pim-$id"
    if [[ ! -x "$bin" ]]; then
      bin="$root_dir/build/pim"
    fi
    echo "CHECKPOINT: Running start on PF$id"
    (cd "$root_dir" && sudo "$bin" -l "$lcores" -w "$pci" --file-prefix "pf$id" -- start CDF_${workload}.txt $id > "$result_dir/result_${workload}_${id}.txt") &
    echo "Start on PF$id should be running now."
  fi
done

for entry in "${senders[@]}"; do
  IFS="|" read -r id pci lcores <<< "$entry"
  bin="$root_dir/build/pim-$id"
  if [[ ! -x "$bin" ]]; then
    bin="$root_dir/build/pim"
  fi
  echo "CHECKPOINT: Running senders on VF$id"
  (cd "$root_dir" && sudo "$bin" -l "$lcores" -w "$pci" --file-prefix "vf$id" -- send CDF_${workload}.txt $id > "$result_dir/result_${workload}_${id}.txt" 2>&1) &
  echo "Senders on VF$id should be running now."
done

sleep 120

(cd "$root_dir" && sudo killall -r '^pim')
if [[ -n "$start_host" ]]; then
  echo "Killing pim process in 10.32.199.56"
  ssh -n $ssh_opts "$start_target" "cd $start_dir; sudo killall -r '^pim'"
fi
