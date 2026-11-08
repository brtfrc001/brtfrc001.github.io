---
title: Wazuh and Suricata Installation
date: 2026-11-08
categories: Lab
tags: SOC
toc: true
mermaid: true
share: true
attachmentLinks: assets/images/Task1-Wazuh_and_Suricata_Installation
media_subpath: assets/images/Task1-Wazuh_and_Suricata_Installation/
---

I set up VM 1 with the Wazuh manager, indexer, and dashboard at 10.10.10.8, and they installed successfully. I also provisioned VM 2 at 10.10.10.9 to host the Suricata engine and the Wazuh agent.
## Wazuh Server and Infrastructure Setup
![[SOC Training/Tasks/Attachments/Pasted image 20261108174002.png|SOC Training/Tasks/Attachments/Pasted image 20261108174002.png]]
## Wazuh server 
![[Attachments/Pasted image 20260930154029.png|Attachments/Pasted image 20260930154029.png]]
refer to https://documentation.wazuh.com/current/quickstart.html for hardware requirements.
using the commmand: `curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh && sudo bash ./wazuh-install.sh -a`, installation of the three components, the manager the dashboard and the indexer completed and I used the credentials it gave me to login to the web interface.
## Wazuh Agent Deployment
I installed and ran the Wazuh agent, registering it to the manager using `sudo /var/ossec/bin/agent-auth -m 10.10.10.8 -A raneem-agent-1`.
![[Attachments/Pasted image 20260930154100.png|Attachments/Pasted image 20260930154100.png]]
Wazuh agent service is runnning.
![[Attachments/Pasted image 20260930154206.png|Attachments/Pasted image 20260930154206.png]]
The dashboard confirmed my agent successfully connected.
## Suricata Installation
refer to page https://docs.suricata.io/en/latest/quickstart.html#installation for installation instructions.
I installed Suricata on the Ubuntu endpoint and verified it was running. 
![[Attachments/Pasted image 20260930154943.png|Attachments/Pasted image 20260930154943.png]]