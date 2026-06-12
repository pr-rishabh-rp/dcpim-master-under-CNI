
#include "config.h"
#include <rte_ip.h>
#include <rte_common.h>
struct Params params = {
    .index = 2,
    .BDP = 7,	// Need to change this to appropriate BDP
    .small_flow_thre = 7,
    .mss = 1460,
    .priority_limit = 6,
    .bandwidth = 10000000000,	// TODO: Need to change this as well to 25Gbps
    // .ip is the node's own identity. It is OVERRIDDEN at runtime in main() from
    // the self-id argument (e.g. "send CDF.txt 3" -> 10.0.0.3). This static value
    // is only a fallback if no self-id is passed.
    .ip = IPv4(10, 0, 0, 2),
    .pim_beta = 5,
    .pim_alpha = 0.3,
    .pim_iter_limit = 5,
    .propagation_delay = 0.0000002,
    .clock_bias = 0.0000005,
    .send_port = 0,
    .pim_select_min_iters = 1,
    .batch_tokens = 1,
    .load = 0.5,
    .token_window = 7,
    .token_window_timeout = 1.1,
    // .num_hosts = 8   // OLD placeholder count
    .num_hosts = 4
};

void init_config(struct Params* p) {
#if 0	// OLD hardcoded placeholder peer table (5.0.0.10.. / 00:01:E8:8B:2E:E4).
	// Kept for posterity. It matched nothing in this deployment, so every
	// PIM_START was addressed to a MAC no VF owns and got dropped.
	p->dst_ips[0] = IPv4(5, 0, 0, 10);
	p->dst_ips[1] = IPv4(6, 0, 0, 10);
	p->dst_ips[2] = IPv4(7, 0, 0, 10);
	p->dst_ips[3] = IPv4(8, 0, 0, 10);
	p->dst_ips[4] = IPv4(9, 0, 0, 10);
	p->dst_ips[5] = IPv4(10, 0, 0, 10);
	p->dst_ips[6] = IPv4(11, 0, 0, 10);
	p->dst_ips[7] = IPv4(12, 0, 0, 10);
	p->dst_ethers[0].addr_bytes[0] = 0x00;
	p->dst_ethers[0].addr_bytes[1] = 0x01;
	p->dst_ethers[0].addr_bytes[2] = 0xE8;
	p->dst_ethers[0].addr_bytes[3] = 0x8B;
	p->dst_ethers[0].addr_bytes[4] = 0x2E;
	p->dst_ethers[0].addr_bytes[5] = 0xE4;
	// ... dst_ethers[1..7] were all the same placeholder 00:01:E8:8B:2E:E4 ...
#endif

	/* Real peer table, aligned with vf_mapping.csv.
	 * dst_ips[i] and dst_ethers[i] MUST describe the SAME node (same index).
	 * NOTE: these MACs must stay in sync with the pinned VF MACs
	 * (ip link set enp193s0np0 vf N mac ...) and the start node's PF MAC. */
	p->num_hosts = 4;
	p->dst_ips[0] = IPv4(10, 0, 0, 2);	// node 2: start, remote PF
	p->dst_ips[1] = IPv4(10, 0, 0, 3);	// node 3: send, VF c1:08.0
	p->dst_ips[2] = IPv4(10, 0, 0, 4);	// node 4: send, VF c1:08.1
	p->dst_ips[3] = IPv4(10, 0, 0, 5);	// node 5: send, VF c1:08.2

	/* node 2 (start / remote PF)  00:15:4d:16:5e:c5 */
	p->dst_ethers[0].addr_bytes[0] = 0x00;
	p->dst_ethers[0].addr_bytes[1] = 0x15;
	p->dst_ethers[0].addr_bytes[2] = 0x4d;
	p->dst_ethers[0].addr_bytes[3] = 0x16;
	p->dst_ethers[0].addr_bytes[4] = 0x5e;
	p->dst_ethers[0].addr_bytes[5] = 0xc5;
	/* node 3 (VF c1:08.0)  16:d4:c1:b9:2b:9b */
	p->dst_ethers[1].addr_bytes[0] = 0x16;
	p->dst_ethers[1].addr_bytes[1] = 0xd4;
	p->dst_ethers[1].addr_bytes[2] = 0xc1;
	p->dst_ethers[1].addr_bytes[3] = 0xb9;
	p->dst_ethers[1].addr_bytes[4] = 0x2b;
	p->dst_ethers[1].addr_bytes[5] = 0x9b;
	/* node 4 (VF c1:08.1)  fa:ea:5a:00:9e:be */
	p->dst_ethers[2].addr_bytes[0] = 0xfa;
	p->dst_ethers[2].addr_bytes[1] = 0xea;
	p->dst_ethers[2].addr_bytes[2] = 0x5a;
	p->dst_ethers[2].addr_bytes[3] = 0x00;
	p->dst_ethers[2].addr_bytes[4] = 0x9e;
	p->dst_ethers[2].addr_bytes[5] = 0xbe;
	/* node 5 (VF c1:08.2)  8e:bc:f0:19:fd:6f */
	p->dst_ethers[3].addr_bytes[0] = 0x8e;
	p->dst_ethers[3].addr_bytes[1] = 0xbc;
	p->dst_ethers[3].addr_bytes[2] = 0xf0;
	p->dst_ethers[3].addr_bytes[3] = 0x19;
	p->dst_ethers[3].addr_bytes[4] = 0xfd;
	p->dst_ethers[3].addr_bytes[5] = 0x6f;

	params.token_window_timeout_cycle = (uint64_t) (params.token_window_timeout * params.BDP * 1500 * 8
 	 / params.bandwidth * rte_get_timer_hz());

}
