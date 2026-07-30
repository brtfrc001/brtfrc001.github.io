---
layout: post
title: "MAC Flooding Lab"
author: "me"
categories: Lab
tags: pentesting networking mac-flooding
---

Hey there, I made this lab for my pentesting lab assignment as part of the course in my major as an information security senior student.

In this lab MAC flooding attack will be demonstrated targeting the switch so we're operating on layer 2 of the OSI model the data link layer.

On windows setting up the simulation environment using GNS3, you can find tutorials on how to get things started on YT. In short I used GNS3 GUI, GNS3 VM, kali VM — on VMware hypervisor — and Cisco switch image file as the structuring parts of the environment.

The network consisting of kali virtual machine (attacker), PC1, PC2 and a switch it will be connected like shown below.

<figure>
  <img src="/assets/images/mac-flooding-lab/network-setup.png" alt="Network topology showing Kali VM, PC1, PC2 connected to a switch">
  <figcaption>Network topology setup for MAC flooding lab</figcaption>
</figure>

<figure>
  <img src="/assets/images/mac-flooding-lab/gns3-gui.png" alt="GNS3 GUI interface running on Windows">
  <figcaption>GNS3 GUI in Windows showing the network topology</figcaption>
</figure>

I configured the switch, anyway our concern is the mac address table — that is stored in CAM (content addressable memory) — shown below…

<figure>
  <img src="/assets/images/mac-flooding-lab/switch-terminal.png" alt="Cisco switch terminal showing MAC address table">
  <figcaption>Switch terminal in enable mode displaying MAC address table</figcaption>
</figure>

In this lab our switch does not restrict every port to a single MAC address nor applies any security policy. This insecure setup will allow attack attempt to succeed.

For context i added a new virtual network adapter in VMware settings that will connect VMs with GNS3. To ensure the connection between Kali VM and GNS3 VM, Let's view the IP configuration in both VMs ..

<figure>
  <img src="/assets/images/mac-flooding-lab/gns3-vm-ip-config.png" alt="GNS3 VM IP configuration showing network settings">
  <figcaption>IP configurations in GNS3 VM</figcaption>
</figure>

<figure>
  <img src="/assets/images/mac-flooding-lab/kali-vm-ip-config.png" alt="Kali Linux VM IP configuration showing network settings">
  <figcaption>IP configurations in Kali VM</figcaption>
</figure>

They are both connected to the same network adapter `eth0`, and sending a ping request from kali to the other VM was received successfully. this is part of the lab setup and essential to connect kali VM to GNS3 simulation environment.

Now that everything is ready, let's start the attack shall we …

<figure>
  <img src="/assets/images/mac-flooding-lab/attacker-machine.png" alt="Kali Linux machine running macof attack">
  <figcaption>Attacker machine launching MAC flooding attack</figcaption>
</figure>

In the first attack we will be using `macof` command specifying `192.168.0.1` the gateway of `vlan1` which is where the switch receives requests to assign MAC addresses to physical interfaces (ports) such as `g0/0, g0/1.. etc.`

What it does is basically filling the CAM table — of limited memory — with a huge number of fake MAC addresses until it no more act as a proper switch, Instead broadcasts all received traffic to all ports just like a `hub.`

Let's view the CAM table one more time…

<figure>
  <img src="/assets/images/mac-flooding-lab/mac-address-table.png" alt="Switch terminal showing overflowed MAC address table">
  <figcaption>Switch terminal showing MAC addresses assigned to interfaces after flooding attack</figcaption>
</figure>

This is called MAC flooding, now as the attacker is part of the network all the traffic is arriving at their doorstep, potentially causing sniffing attack..

I hope this was useful, see you later.
