---
title: Suricata Network Sensor
date: 2026-11-15
categories: Lab
tags:
toc: true
mermaid: true
share: true
slug: 2026-11-15-Task8-suricata-network-sensor
attachment:
  send: true
  folder: assets/images/Task8-suricata-network-sensor
---

In this lab we are converting the behavior of Suricata on the Wazuh agent machine, so that it has observability on network traffic of three machines, the host machine and the Wazuh sever virtual machine and itself (Wazuh agent endpoint virtual machine), we're gonna do that by setting an additional virtual network adapter (host-only) in VMware settings to both VMs and configuring Suricata to monitor its traffic.

Source: https://nextwork.ai/projects/c9d932cd-4c28-44fa-9243-1f7d748bc735
## Setup
This is what it'll look like at the end of this task.
![Pasted image 20261021213148](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021213148.png)
## Virtual machines' network adapter
We are going to configure the network adapters on two virtual machines and test the connection in the following steps.
### Setting static IPs
This is a crucial for Suricata to be available on both the Wazuh server and the agent endpoint.
#### Wazuh server endpoint
Add a second network adapter in VMware machine's settings, and set it to `host-only`.
![Pasted image 20261021191605](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021191605.png)
Edit network configuration file, to have a static IP address for the new network we made by adding that adapter.
![Pasted image 20261021190639](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021190639.png)
Apply the new configurations.
![Pasted image 20261021190701](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021190701.png)
#### Wazuh agent endpoint
Same as what we did to the server, we add a network adapter with the same type `host-only`.
![Pasted image 20261021191756](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021191756.png)
Set static IP.
![Pasted image 20261021194443](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021194443.png)
Apply
![Pasted image 20261021194554](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021194554.png)
### Testing connection
Pinged from agent endpoint to server's and it is successful.
![Pasted image 20261021195608](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021195608.png)
And vice versa, it's successful.
![Pasted image 20261021195733](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021195733.png)
## Suricata Network Configurations
Setting `HOME_NET` variable to the new network address, that we just made.
![Pasted image 20261021201408](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021201408.png)
And set the interface to `enp2s5`, this is of the `host-only` network adapter we set up earlier.
![Pasted image 20261021203932](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021203932.png)
I restarted it and it is running.
![Pasted image 20261021204505](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021204505.png)
## Testing Suricata as a Network Intrusion Detection System (NIDS)
Attacking the agent's endpoint from the windows host.
Using `nmap` on target `192.168.230.129`, notice this is the address on our `host-only` network.
![Pasted image 20261021205511](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021205511.png)
Going to the Wazuh dashboard, and filtering suricata alerts.
![Pasted image 20261021210706](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021210706.png)
View one of them, of the description `ET SCAN Potential VNC Scan 5800-5820`. 
Notice the `data.dest_ip` is same as the agent's endpoint and the `data.src_ip` is of the host machine's (windows).
![Pasted image 20261021210808](assets/images/Task8-suricata-network-sensor/Pasted%20image%2020261021210808.png)
Full alert document JSON:
```
{
  "_index": "wazuh-alerts-4.x-2026.10.21",
  "_id": "mX2XX6EBxRvBlJIcHnG_",
  "_score": 1,
  "_source": {
    "agent": {
      "ip": "10.10.10.9",
      "name": "raneem-agent-1",
      "id": "001"
    },
    "manager": {
      "name": "raneem-VMware-Virtual-Platform"
    },
    "data": {
      "ip_v": "4",
      "in_iface": "enp2s5",
      "src_ip": "192.168.230.1",
      "src_port": "39247",
      "event_type": "alert",
      "alert": {
        "severity": "2",
        "signature_id": "2002910",
        "rev": "6",
        "metadata": {
          "updated_at": [
            "2019_07_26"
          ],
          "confidence": [
            "Medium"
          ],
          "created_at": [
            "2010_07_30"
          ],
          "signature_severity": [
            "Informational"
          ]
        },
        "gid": "1",
        "signature": "ET SCAN Potential VNC Scan 5800-5820",
        "action": "allowed",
        "category": "Attempted Information Leak"
      },
      "flow_id": "998178250801870.000000",
      "dest_ip": "192.168.230.129",
      "proto": "TCP",
      "dest_port": "5801",
      "pkt_src": "wire/pcap",
      "flow": {
        "src_ip": "192.168.230.1",
        "src_port": "39247",
        "pkts_toserver": "1",
        "dest_ip": "192.168.230.129",
        "start": "2026-10-21T20:51:39.363478+0300",
        "bytes_toclient": "0",
        "bytes_toserver": "60",
        "pkts_toclient": "0",
        "dest_port": "5801"
      },
      "timestamp": "2026-10-21T20:51:39.363478+0300",
      "direction": "to_server"
    },
    "rule": {
      "firedtimes": 15,
      "mail": false,
      "level": 3,
      "description": "Suricata: Alert - ET SCAN Potential VNC Scan 5800-5820",
      "groups": [
        "ids",
        "suricata"
      ],
      "id": "86601"
    },
    "decoder": {
      "name": "json"
    },
    "input": {
      "type": "log"
    },
    "@timestamp": "2026-10-21T17:51:39.704Z",
    "location": "/var/log/suricata/eve.json",
    "id": "1792605099.20694991",
    "timestamp": "2026-10-21T20:51:39.704+0300"
  },
  "fields": {
    "timestamp": [
      "2026-10-21T17:51:39.704Z"
    ],
    "@timestamp": [
      "2026-10-21T17:51:39.704Z"
    ],
    "data.timestamp": [
      "2026-10-21T17:51:39.363Z"
    ]
  }
}
```

#### Alert key values

- "src_ip": "192.168.230.1"
- "dest_ip": "192.168.230.129"
- "description": "Suricata: Alert - ET SCAN Potential VNC Scan 5800-5820"

The gateway's IP `192.168.230.1` is the host's in this case where the attack came from, and `192.168.230.129` is the victim's (Wazuh agent VM), the alert can be more specific by writing a custom detection rule in Wazuh, and Suricata detection rules as well, which we're going to do in the next labs. 