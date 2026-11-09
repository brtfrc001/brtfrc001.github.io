---
title: Integration of Suricata with Wazuh
date: 2026-11-09
categories: Lab SOC
tags: wazuh suricata IDS NIDS
toc: true
mermaid: true
share: true
attachmentLinks: assets/images/Task2-suricata_wazuh_integration
media_subpath: assets/images/Task2-suricata_wazuh_integration/
---

This is the integration of IDS (Wazuh) with the network monitoring tool Suricata, below is the lab setup as we've established in the previous post.
![[SOC Training/Tasks/Attachments/Pasted image 20261109202902.png|SOC Training/Tasks/Attachments/Pasted image 20261109202902.png]]

## Suricata Configuration
Based on the reference: https://documentation.wazuh.com/current/proof-of-concept-guide/integrate-network-ids-suricata.html
I modified the configurations in `/etc/suricata/suricata.yaml`, one of the variables to edit is `HOME_NET: "<UBUNTU_IP>"` and it means the IP on the current machine, in my case the agent's which is `10.10.10.9`.
Also updated `/var/ossec/etc/ossec.conf` to point to Suricata logs in `/var/log/suricata/eve.json` so they could be sent to the Wazuh manager.
![[Attachments/Pasted image 20260930155031.png|Attachments/Pasted image 20260930155031.png]]
View service status.
![[Attachments/Pasted image 20260930155057.png|Attachments/Pasted image 20260930155057.png]]
## Rule Updates and Traffic Simulation
Although Suricata was running, it didn't have any rules loaded yet. I ran `sudo suricata-update` to get the official rule set, restarted the service, and checked the logs to ensure it successfully loaded the rules. 
![[Attachments/Pasted image 20260930155157.png|Attachments/Pasted image 20260930155157.png]]
From the server terminal, I started pinging the agent endpoint to generate network traffic.
![[Attachments/Pasted image 20260930155300.png|Attachments/Pasted image 20260930155300.png]]
## Alert Verification
The Wazuh dashboard shows a "Suricata: Alert" for the ICMP traffic. This means the server successfully received the logs and the integration is working.
![[Attachments/Pasted image 20260930155310.png|Attachments/Pasted image 20260930155310.png]]