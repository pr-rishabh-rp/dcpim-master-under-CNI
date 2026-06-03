import sys
import socket
import struct
import netifaces as ni
import csv
# ether_addrs = ["00:01:e8:8b:2e:e4", "00:01:e8:8b:2e:e4", "00:01:e8:8b:2e:e4", "00:01:e8:8b:2e:e4", "00:01:e8:8b:2e:e4", "00:01:e8:8b:2e:e4", "00:01:e8:8b:2e:e4", "00:01:e8:8b:2e:e4"]
ether_addrs = []
# TODO: Set ip_prefix to your subnet (comma-separated for IPv4(...) literal), e.g. "192,168,50".
def construct_ip(small_ip, large_ip, ip_prefix = "10,0,0"):
    num_dst = large_ip - small_ip + 1
    dst_ips = ""
    for i in range(num_dst):
        dst_ips += "\tp->dst_ips[{}] = IPv4({}, {});".format(i, ip_prefix, small_ip + i)
        dst_ips += "\n"
    return num_dst, dst_ips

def construct_ip_list(ips):
    dst_ips = ""
    for i, ip in enumerate(ips):
        parts = ip.split(".")
        dst_ips += "\tp->dst_ips[{}] = IPv4({}, {}, {}, {});".format(
            i, parts[0], parts[1], parts[2], parts[3])
        dst_ips += "\n"
    return len(ips), dst_ips

def ip2int(addr):
    return struct.unpack("!I", socket.inet_aton(addr))[0]

def read_arp_and_ip(file = "/proc/net/arp"):
    f = open(file, "r")
    lines = f.readlines()[1:]
    dict_ip = {}
    for line in lines:
        e = line.split()
        ip = e[0]
        eth = e[3]
        # TODO: Filter ARP entries by your subnet (e.g., "192.168").
        if "10.10" in ip:
            dict_ip[ip2int(ip)] = eth

    # read ip 
    # TODO: Replace 'eno1d1' with the NIC/VF interface name used for dcPIM traffic. // Statically assign IP and MAC to each VF and store those addresses in vf_mapping.csv. Then use something like "python config.py --vf-idx 7 --mapping vf_mapping.csv --total-hosts 32" to run for each VF
    ip = ni.ifaddresses('eno1d1')[ni.AF_INET][0]['addr']
    ether = ni.ifaddresses('eno1d1')[ni.AF_LINK][0]['addr']
    dict_ip[ip2int(ip)] = ether

    for key in sorted(dict_ip.keys()):
        ether_addrs.append(dict_ip[key])
    print (ether_addrs)
    return ip

def read_mapping(path):
    entries = []
    with open(path, "r") as f:
        reader = csv.reader(f)
        for row in reader:
            if not row:
                continue
            if row[0].strip().lower() in ("id", "vf_id", "index"):
                continue
            if row[0].strip().startswith("#"):
                continue
            if len(row) < 3:
                continue
            entries.append({
                "id": int(row[0].strip()),
                "ip": row[1].strip(),
                "mac": row[2].strip()
            })
    return entries

def construct_ethers(addrs):
    i = 0
    output = ""
    for addr in addrs:
        parts = addr.split(":")
        j = 0
        for p in parts:
            output += "\tp->dst_ethers[{}].addr_bytes[{}] = {};\n".format(i, j, "0x" + p.upper())
            j += 1
        i += 1
    return output

def get_arg_value(flag):
    if flag in sys.argv:
        idx = sys.argv.index(flag)
        if idx + 1 < len(sys.argv):
            return sys.argv[idx + 1]
    return None

def main():
    print ("CHECKPOINT: We are inside config.py")
    mapping = get_arg_value("--mapping")
    self_id = get_arg_value("--self-id")
    if mapping is not None:
        entries = read_mapping(mapping)
        if self_id is None:
            print ("Usage: python config.py --mapping <csv> --self-id <id>")
            sys.exit(1)
        self_id = int(self_id)
        self_entry = None
        for e in entries:
            if e["id"] == self_id:
                self_entry = e
                break
        if self_entry is None:
            print ("self-id not found in mapping:", self_id)
            sys.exit(1)
        ips = [e["ip"] for e in entries]
        macs = [e["mac"] for e in entries]
        num_dst, dst_ips = construct_ip_list(ips)
        ip = self_entry["ip"]
        index = self_entry["id"]
        num_hosts = len(entries)
    else:
        small_ip = sys.argv[1]
        large_ip = sys.argv[2]
        num_dst, dst_ips = construct_ip(int(small_ip), int(large_ip))
        # config_string.format(ip_str)
        ip = read_arp_and_ip()
        index = int(ip.split(".")[3]) - int(small_ip)
        num_hosts = int(large_ip) - int(small_ip) + 1
    ip_str =  "IPv4(" + ip.replace(".", ",") + ")"
    print ("CHECKPOINT: Creating config2.c")
    config_string = """
#include "config.h"
#include <rte_ip.h>
#include <rte_common.h>
struct Params params = {{
    .index = {0},
    // TODO: Set BDP (in packets) for our link bandwidth and RTT. // Need to get RTT.
    .BDP = 382,
    // TODO: Tune small-flow threshold (in packets) for our workload/BDP.
    .small_flow_thre = 382,
    .mss = 1460,
    .priority_limit = 6,
    // TODO: Set link bandwidth in bps (per host/VF).
    .bandwidth = 25000000000,
    .ip = {1},
    .pim_beta = 5,
    .pim_alpha = 1.1,
    .pim_iter_limit = 3,
    // TODO: Set propagation delay (seconds) for your topology. // Keeping it unchanged to 0.2 µs
    .propagation_delay = 0.0000002,
    // TODO: Set clock bias (seconds) if you need non-zero skew.
    .clock_bias = 0.0000005,
    // TODO: Set DPDK TX port index for your NIC/VF. // Need to connect DPDK with VFs yet. // Port 0 is fine.
    .send_port = 0,
    .pim_select_min_iters = 1,
    .batch_tokens = 5,
    // TODO: Tune offered load if you need a different load level. // Keeping the same.
    .load = 0.5,
    .token_window = 20,
    .token_window_timeout = 1.1,
    // TODO: num_hosts derives from small/large IP args; update those in run.sh. // Dont understand yet. Need to look into it.
    .num_hosts = {2}
}};
""".format(index, ip_str, num_hosts)
    statement = dst_ips
    if mapping is not None:
        statement += construct_ethers(macs)
    else:
        statement += construct_ethers(ether_addrs)
    statement += "\tparams.token_window_timeout_cycle = (uint64_t) (params.token_window_timeout * params.BDP * 1500 * 8 \n \t / params.bandwidth * rte_get_timer_hz());\n"
    init_string= """
void init_config (struct Params* p) {{
{0}
}}
""".format(statement)

    f = open("src/config2.c", "w+")
    f.write(config_string)
    f.write(init_string)
    f.close()
main()
