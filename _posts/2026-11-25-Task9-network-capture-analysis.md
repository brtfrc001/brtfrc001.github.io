---
title: Network Capture Analysis
date: 2026-11-25
categories: SOC Lab
tags:
  - network-analysis
  - pcap
  - wireshark
toc: true
mermaid: true
share: true
slug: 2026-11-25-Task9-network-capture-analysis
attachment:
  send: true
  folder: assets/images/Task9-network-capture-analysis
---


In this post we're analyzing a PCAP file using Wireshark and our goal is to find:

- Victim IP and OS 
- C2 server IP and geolocation 
- Beacon timing

To simplify some terminology, C2 is short for **Command & Control** and it refers to the role a malicious server is taking in controlling the victim's machine, and the command part, for example to command the victim's machine to send TCP SYN requests in an automated way to flood a target server and cause it to fail to continue its runtime or task, which is called a **Denial of Service (DoS)** attack, furthermore if the threat actor had control over too many victims' machines, then they would initiate the attack from everywhere all at once which is known as **Distributed Denial of Service (DDoS)** attack. 

The victim machines (compromised endpoints) that are controlled by the threat actor but not yet utilized in a way that makes them detected - not that they are undetectable - are called **Zombies**, **Bots** or **Botnet**, they occasionally send requests to the C2 server, the frequency, the timing and even the protocol used is based on the beacon, which is a software on the victim side, the **beaconing** as a technique is the heart of the C2 tactic.

You might ask how are the compromised endpoints or the zombies are not detected while they are literally sending requests to a malicious IP? well there are many detection evasion techniques utilized by threat actors, but before even bringing that deep topic into the conversation, the malicious IP or Domain Name may not yet be known to be malicious, only when an incident happens due to a particular group or an **Advanced Persistent Threat (APT)** starting a campaign on their target, then an investigation will take place and find malicious IPs and other **Indicators of Compromise (IoC)** to update **Cyber Threat Intelligence (CTI)** databases or feeds with.

I wanted to bring in more context to not be misunderstood when I explained what a botnet is, with that said let's dive in.
## DNS
Filtering `dns` there's 3 endpoints involved, the DNS servers and the victim.
![Pasted image 20261026145027](assets/images/Task9-network-capture-analysis/Pasted%20image%2020261026145027.png)
Because of what could be misinterpreted as abnormal behavior, that it is using so many different ports for DNS, at first I thought:

> This number of ports are opened to hide the persistence and command and control port and it is a sub-technique of Traffic Signaling called Port Knocking according to MITRE ATT&CK(https://attack.mitre.org/techniques/T1205) as part of the Command and Control tactic.

However, the packets' byte sizes are not constant, differing in a range of (200-500 bytes) which eliminates the C2 communication suspicion, this behavior is benign and the randomization of source ports is even secure for DNS as a measure against DNS spoofing , because it makes it harder on the attacker to know which is used for sending the DNS request.
![Pasted image 20261026145455](assets/images/Task9-network-capture-analysis/Pasted%20image%2020261026145455.png)
## ICMP
Two IPs appear in the `icmp` filter, and one of which is a private IP and the other is an external one, an internal IP sent a huge number of PING requests to `157.230.93.100` in a time window (81-341) in seconds that means 440 packets in 260 seconds in a rate 2 packets every second, which indicates beaconing pattern, and the host `10.0.0.60` is compromised and acts exactly like a zombie in a botnet.
![Pasted image 20261026150816](assets/images/Task9-network-capture-analysis/Pasted%20image%2020261026150816.png)
Next, in the ethernet destination header, it is shown that the geolocation is `VantivaUSA`, which means that the geolocation of the attacker's IP `157.230.93.100` is USA.
![Pasted image 20261026153823](assets/images/Task9-network-capture-analysis/Pasted%20image%2020261026153823.png)
Also running online search in the `AbuseIPDB` database confirms it.
![Pasted image 20261026154321](assets/images/Task9-network-capture-analysis/Pasted%20image%2020261026154321.png)
The image below shows the delta time for ICMP requests sent from compromised host to the baecon's server, the timing is 0.5 seconds.
![Pasted image 20261026205720](assets/images/Task9-network-capture-analysis/Pasted%20image%2020261026205720.png)
## HTTP
Filter the victims HTTP traffic to find OS, below the `user-agent` header showing `Microsoft-Windows` which means OS is windows.
![Pasted image 20261026153249](assets/images/Task9-network-capture-analysis/Pasted%20image%2020261026153249.png)
## Mapping to the MITRE ATT&CK framework

| **MITRE ATT&CK Tactic**  | **Parent Technique**                     | **Mentioned in Post**              | **Context in Analysis**             |
| ------------------------ | ---------------------------------------- | ---------------------------------- | ----------------------------------- |
| **Command and Control**  | Non-Application Layer Protocol (`T1095`) | ICMP beaconing to `157.230.93.100` | Observed C2 communication           |
| **Command and Control**  | Traffic Signaling (`T1205`)              | Port Knocking (DNS source ports)   | Ruled out as benign DNS behavior    |
| **Impact**               | Network Denial of Service (`T1498`)      | DoS, DDoS, and TCP SYN flood       | Conceptual background               |
| **Resource Development** | Compromise Infrastructure (`T1584`)      | Zombies, Bots, and Botnet          | Conceptual background & victim role |

_Note: DNS spoofing is also mentioned as a defensive context for port randomization, which falls conceptually under network-level spoofing/Adversary-in-the-Middle behaviors rather than an observed attack in the PCAP._

**Sources**:

- MITRE ATT&CK – Traffic Signaling (`T1205`): [https://attack.mitre.org/techniques/T1205/](https://attack.mitre.org/techniques/T1205/)
    
- MITRE ATT&CK – Network Denial of Service (`T1498`): [https://attack.mitre.org/techniques/T1498/](https://attack.mitre.org/techniques/T1498/)
    
- MITRE ATT&CK – Non-Application Layer Protocol (`T1095`): [https://attack.mitre.org/techniques/T1095/](https://attack.mitre.org/techniques/T1095/)
    
- MITRE ATT&CK – Compromise Infrastructure (`T1584`): [https://attack.mitre.org/techniques/T1584/005/](https://attack.mitre.org/techniques/T1584/005/)
