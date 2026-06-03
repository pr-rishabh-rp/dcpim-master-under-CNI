echo "CHECKPOINT: Inside run.sh"
host=""
mapping=""
self_id=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mapping)
      mapping="$2"
      shift 2
      ;;
    --self-id)
      self_id="$2"
      shift 2
      ;;
    *)
      host="$1"
      shift
      ;;
  esac
done

# ping the number of end hosts (ARP discovery mode only)
if [[ -z "$mapping" ]]; then
  for (( c=2; c<=$host; c++ ))
  do
     # TODO: Replace 10.10.1.* with our host/VF IP range to populate ARP.
     ping 10.0.0.$c  -w 5
  done
fi

# reserve the numa memory
echo "CHECKPOINT: (Potentially) Inside 10.32.199.56, about to set hugepages using sudo sh -c"
sudo sh -c 'for i in /sys/devices/system/node/node*/hugepages/hugepages-2048kB/nr_hugepages; do echo 4096 > $i; done'

# config
if [[ -n "$mapping" ]]; then
  if [[ -z "$self_id" ]]; then
    echo "Usage: run.sh --mapping <csv> --self-id <id>"
    exit 1
  fi
  echo "CHECKPOINT: About to run config.py"
  python3 config.py --mapping "$mapping" --self-id "$self_id"
else
  python3 -m pip install netifaces
  # TODO: Set the smallest and largest IP suffix for our host/VF range.
  python3 config.py 2 $host
fi
# compile the code
# TODO: Set RTE_SDK to our DPDK install path. // Set to my installation path
export RTE_SDK=/usr/src/dpdk-18.11

echo "About to run make in root directory of repository"
make clean
make
