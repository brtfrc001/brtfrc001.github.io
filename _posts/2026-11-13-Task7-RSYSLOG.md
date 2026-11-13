---
title: RSYSLOG Integration with Wazuh
date: 2026-11-13
categories: Lab SOC
tags: IDS EDS
toc: true
mermaid: true
share: true
slug: 2026-11-13-Task7-RSYSLOG
attachment:
  send: true
  folder: assets/images/Task7-RSYSLOG
---

`rsyslog` is a logging daemon on Linux systems. It supports integration with modern observability tools such as Elasticsearch and in our case Wazuh. It also supports TLS, so it encrypts the logs before sending them over the network to keep system information secure.
Furthermore, `rsyslog` is a modern alternative of the traditional `syslog` and both are a default logging daemons on different Linux distributions.

The main configuration file is `/etc/rsyslog.conf`, it is set to log standard system logs by default, while user customized configurations can be added to `/etc/rsyslog.d/` directory as `costum-1-example.conf` file format.

Sources:
- https://docs.rsyslog.com/doc/index.html
- [TLS-protected syslog](https://docs.rsyslog.com/doc/tutorials/tls.html)
## Lab setup
This is the lab setup with the previous labs tasks done plus this post's task which is integrating `rsyslog`.
![Pasted image 20261114011042](assets/images/Task7-RSYSLOG/Pasted%20image%2020261114011042.png)
## Installation
It seems, it is already installed on Ubuntu or my `raneem-agent-1` endpoint. It is running.
![Pasted image 20261019134326](assets/images/Task7-RSYSLOG/Pasted%20image%2020261019134326.png)
## Integration
### Wazuh agent side
#### Steps
##### Configuration
To enable encrypted log forwarding to Wazuh server, I'll add a new configuration file `/etc/rsyslog.d/51-forward-wazuh.conf`. Putting Wazuh server's hostname `raneem-VMware-Virtual-Platform` in as the target. 
![Pasted image 20261019142510](assets/images/Task7-RSYSLOG/Pasted%20image%2020261019142510.png)
##### Alternative way to configure
Another way is to add the following line to `/etc/rsyslog.conf`.
```
*.* action(type="omfwd" target="<WAZUH_SERVER_IP>" port="<PORT>" protocol="tcp")
```
Editing below.
![Pasted image 20261019150750](assets/images/Task7-RSYSLOG/Pasted%20image%2020261019150750.png)
##### Last step
Restart the `rsyslog` daemon to apply new configurations.
##### Connection verification
To insure hostname is resolved I send ICMP message from agent endpoint to the  server's.
![Pasted image 20261019142829](assets/images/Task7-RSYSLOG/Pasted%20image%2020261019142829.png)
### Wazuh server side
Now we go to the server where Wazuh manager is. Editing `/var/ossec/etc/ossec.conf`, I added the `<remote>` block configurations.
Based on source: https://wazuh.com/blog/how-to-configure-rsyslog-client-to-send-events-to-wazuh/
![Pasted image 20261019143949](assets/images/Task7-RSYSLOG/Pasted%20image%2020261019143949.png)
Restart the manager.
![Pasted image 20261019144201](assets/images/Task7-RSYSLOG/Pasted%20image%2020261019144201.png)
## Testing
In the wazuh dashboard it requires an alert to be triggered so instead I'm going to find the test log in `archive.json`. By sending a test message in the agent using `logger`.
![Pasted image 20261019154306](assets/images/Task7-RSYSLOG/Pasted%20image%2020261019154306.png)
And view the log file using `tail` and `grep` commands.
![Pasted image 20261019154030](assets/images/Task7-RSYSLOG/Pasted%20image%2020261019154030.png)
#### Test and view in alerts dashboard
Sending a message that triggers an alert.
![Pasted image 20261019155402](assets/images/Task7-RSYSLOG/Pasted%20image%2020261019155402.png)
Then we can see it in the discover alert dashboard. Click view single document.
![Pasted image 20261019155554](assets/images/Task7-RSYSLOG/Pasted%20image%2020261019155554.png)
The complete JSON log.
```json
{
  "_index": "wazuh-alerts-4.x-2026.10.19",
  "_id": "eAY3VKEBkjY_zUhocE3Y",
  "_score": 1,
  "_source": {
    "predecoder": {
      "hostname": "raneem-agent-1",
      "program_name": "sshd",
      "timestamp": "Oct 19 12:51:10"
    },
    "agent": {
      "ip": "10.10.10.9",
      "name": "raneem-agent-1",
      "id": "001"
    },
    "manager": {
      "name": "raneem-VMware-Virtual-Platform"
    },
    "data": {
      "srcuser": "testuser",
      "srcip": "10.10.10.9"
    },
    "rule": {
      "mail": false,
      "level": 5,
      "hipaa": [
        "164.312.b"
      ],
      "pci_dss": [
        "10.2.4",
        "10.2.5",
        "10.6.1"
      ],
      "tsc": [
        "CC6.1",
        "CC6.8",
        "CC7.2",
        "CC7.3"
      ],
      "description": "sshd: Attempt to login using a non-existent user",
      "groups": [
        "syslog",
        "sshd",
        "authentication_failed",
        "invalid_login"
      ],
      "nist_800_53": [
        "AU.14",
        "AC.7",
        "AU.6"
      ],
      "gdpr": [
        "IV_35.7.d",
        "IV_32.2"
      ],
      "firedtimes": 2,
      "mitre": {
        "technique": [
          "Password Guessing",
          "SSH"
        ],
        "id": [
          "T1110.001",
          "T1021.004"
        ],
        "tactic": [
          "Credential Access",
          "Lateral Movement"
        ]
      },
      "id": "5710",
      "gpg13": [
        "7.1"
      ]
    },
    "decoder": {
      "parent": "sshd",
      "name": "sshd"
    },
    "full_log": "Oct 19 12:51:10 raneem-agent-1 sshd[28631]: Failed password for invalid user testuser from 10.10.10.9 port 22 ssh2",
    "input": {
      "type": "log"
    },
    "@timestamp": "2026-10-19T12:51:12.070Z",
    "location": "journald",
    "id": "1792414272.10125291",
    "timestamp": "2026-10-19T15:51:12.070+0300"
  },
  "fields": {
    "timestamp": [
      "2026-10-19T12:51:12.070Z"
    ],
    "@timestamp": [
      "2026-10-19T12:51:12.070Z"
    ]
  }
}
```