host=$1

# ping the number of end hosts
for (( c=1; c<=$host; c++ ))
do
   # TODO: Replace 10.10.1.* with your host/VF IP range to populate ARP.
   ping 10.10.1.$c  -w 5
done

# reserve the numa memory

sudo sh -c 'for i in /sys/devices/system/node/node*/hugepages/hugepages-2048kB/nr_hugepages; do echo 4096 > $i; done'

# config
pip install netifaces
# TODO: Set the smallest and largest IP suffix for your host/VF range.
python config.py 1 $host
# compile the code
# TODO: Set RTE_SDK to your DPDK install path.
export RTE_SDK=/usr/local/src/dpdk-stable-18.11.10/

make clean
make
