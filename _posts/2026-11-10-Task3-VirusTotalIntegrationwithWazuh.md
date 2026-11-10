---
title: VirusTotal Integration with Wazuh
date: 2026-11-10
categories: Lab SOC
tags: wazuh virustotal
toc: true
mermaid: true
share: true
slug: 2026-11-10-Task3-VirusTotalIntegrationwithWazuh
attachment:
  send: true
  folder: assets/images/Task3-VirusTotalIntegrationwithWazuh
---

VirusTotal is google's threat intelligence database, that checks all common detection engines for an IoC (file hash, IP address, etc.). 
For more refer to official docs: https://documentation.wazuh.com/current/user-manual/capabilities/malware-detection/virus-total-integration.html
## Lab setup
I want to remind you of the lab setup from the previous labs of the category "SOC".
![Pasted image 20261110205727](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261110205727.png)
### Get API Key & Configure Wazuh Integration
We will use public API, it is a REST API, and by registering an account, I then copy my API key at https://www.virustotal.com/gui/my-apikey and paste in `/var/ossec/etc/ossec.conf` in `<integration>` block in the Wazuh server.
Refer to official docs: https://documentation.wazuh.com/current/user-manual/manager/integration-with-external-apis.html 
![Pasted image 20261005135437](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005135437.png)
And then restart to apply new configurations.
![Pasted image 20261005135540](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005135540.png)
To configure VirusTotal to monitor a specific directory, we edit the configurations at `/var/ossec/etc/ossec.conf` again and modify `<syscheck>` section.
![Pasted image 20261005140649](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005140649.png)
And then restart the manager to apply configurations.
![Pasted image 20261005140813](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005140813.png)
## Testing integration
### Steps
To test it we're going to download a malicious file (not real malware it is known file for IDS alert testing) in the endpoint where we're monitoring, after creating the directory `/media/user/software`.
![Pasted image 20261005141256](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005141256.png)
After the malware has been downloaded, let's see the alerts generated in the dashboard.
Searching for `rule.groups: virustotal`
![Pasted image 20261005145544](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005145544.png)
The test failed and the agent isn't being monitored.
### Troubleshooting: Redo integration configurations in the agent endpoint
It seems for the agent endpoint to be included , I must first configure the agent endpoint's own configurations in `/var/ossec/etc/ossec.conf` and modify the `<syscheck>` section, the same I did for server's in the previous steps.
![Pasted image 20261005150035](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005150035.png)
Restart the `wazuh-agent`.
![Pasted image 20261005150132](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005150132.png)
### Retesting
Redo the test.
```
root@raneem-VMware-Virtual-Platform:~# curl -Lo /media/user/software/suspicious-file.exe https://secure.eicar.org/eicar.com
```
![Pasted image 20261005150759](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005150759.png)
Search in the dashboard.
```dql
rule.groups: virustotal
```

![Pasted image 20261005151154](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005151154.png)
Filter more details.
```dql
rule.groups: virustotal and rule.id: 87105 
```
As expected showing one hit, which means it is successfully monitored and produced the alert from rule of the ID: 87105 and this ID means a malicious file was detected. 
![Pasted image 20261005151613](assets/images/Task3-VirusTotalIntegrationwithWazuh/Pasted%20image%2020261005151613.png)
#### Summary of the alert
The alert ID is `wazuh-alerts-4.x-2026.10.05#0IfyC6EBs9a_UfQF136s` and this is the complete JSON format of the generated alert.
```json
{
  "_index": "wazuh-alerts-4.x-2026.10.05",
  "_id": "0IfyC6EBs9a_UfQF136s",
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
      "integration": "virustotal",
      "virustotal": {
        "sha1": "3395856ce81f2b7382dee72602f798b642f14140",
        "malicious": "1",
        "total": "68",
        "found": "1",
        "positives": "66",
        "source": {
          "sha1": "3395856ce81f2b7382dee72602f798b642f14140",
          "file": "/media/user/software/suspicious-file.exe",
          "alert_id": "1791201815.130653",
          "md5": "44d88612fea8a8f36de82e1278abb02f"
        },
        "permalink": "https://www.virustotal.com/gui/file/275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f/detection/f-275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f-1791201560",
        "scan_date": "2026-10-05 11:59:20"
      }
    },
    "rule": {
      "firedtimes": 1,
      "mail": true,
      "level": 12,
      "pci_dss": [
        "10.6.1",
        "11.4"
      ],
      "description": "VirusTotal: Alert - /media/user/software/suspicious-file.exe - 66 engines detected this file",
      "groups": [
        "virustotal"
      ],
      "mitre": {
        "technique": [
          "Exploitation for Client Execution"
        ],
        "id": [
          "T1203"
        ],
        "tactic": [
          "Execution"
        ]
      },
      "id": "87105",
      "gdpr": [
        "IV_35.7.d"
      ]
    },
    "decoder": {
      "name": "json"
    },
    "input": {
      "type": "log"
    },
    "@timestamp": "2026-10-05T12:03:37.922Z",
    "location": "virustotal",
    "id": "1791201817.131462",
    "timestamp": "2026-10-05T15:03:37.922+0300"
  },
  "fields": {
    "timestamp": [
      "2026-10-05T12:03:37.922Z"
    ],
    "@timestamp": [
      "2026-10-05T12:03:37.922Z"
    ]
  }
}
```
Notice `data.integration` is VirusTotal and other info like `data.malicious: "1"` a flag for confirming it is malicious, also `data.positives: "66"` which indicates the number of detection engines that detected it as malicious is 66 engines out of 68 which means it is a highly confident result.