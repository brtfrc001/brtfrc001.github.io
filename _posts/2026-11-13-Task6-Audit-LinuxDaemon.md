---
title: Audit Integration with Wazuh
date: 2026-11-13
categories: Lab SOC
tags: eds ids
toc: true
mermaid: true
share: true
slug: 2026-11-13-Task6-Audit-LinuxDaemon
attachment:
  send: true
  folder: assets/images/Task6-Audit-LinuxDaemon
---

Audit or `auditd` daemon is a service in Linux, it hooks the Linux kernel to watch system calls.
Also there is `auditctl` a tool for control the behavior of `auditd` adding and deleting rules, which are divided to three types:
	- control: rules for configuring the service itself.
	- system file: watching a specific file or directory for read, write and execute permissions.
	- system calls: monitors system calls, which is an interface for user space programs to execute in kernel space. 
Another component is `/etc/audit/rules.d/` directory where user can add custom `file.rules` which is another way to add rules, then reload the daemon to apply them.

Sources:
- https://linux.die.net/man/8/auditd
- https://www.redhat.com/en/blog/configure-linux-auditing-auditd

## `Auditd` and wazuh
We will install the `auditd` service on `raneem-agent-1` endpoint and wazuh agent will automatically send the logs with brief integration step later in the integration section.
## Setup
This is the updated lab setup.
![Pasted image 20261014212804](assets/images/Task6-Audit-LinuxDaemon/Pasted%20image%2020261014212804.png)
## Installation
### Steps
On `raneem-agent1` endpoint, I installed it based on tutorial https://wazuh.com/blog/monitoring-root-actions-on-linux-using-auditd-and-wazuh/ .
As shown below there are yet rules to be added.
![Pasted image 20261014142712](assets/images/Task6-Audit-LinuxDaemon/Pasted%20image%2020261014142712.png)
To add rules, I edited and appended two lines of rules to `etc/audit/rules.d/wazuh.rules` , which watches the execution of any binary by root, also the architecture is specified so that `x86` and `x64` based processors are supported for this rule.
![Pasted image 20261014154123](assets/images/Task6-Audit-LinuxDaemon/Pasted%20image%2020261014154123.png)
Then to apply new rules, I run the next command to reload the rules file.
```
auditctl -R /etc/audit/rules.d/wazuh.rules
```
Then I list the rules applied using `auditctl -l`, and they are successfully listed.
![Pasted image 20261014155836](assets/images/Task6-Audit-LinuxDaemon/Pasted%20image%2020261014155836.png)
## Integration with wazuh
### Steps
To insure wazuh is monitoring `/var/log/audit/audit.log` by adding it as a location of log in `/var/ossec/etc/ossec.conf` as shown below.
![Pasted image 20261014150537](assets/images/Task6-Audit-LinuxDaemon/Pasted%20image%2020261014150537.png)
Restart wazuh agent.
### Testing Integration
Use `sudo` and execute `sudo apt update`.
![Pasted image 20261014155926](assets/images/Task6-Audit-LinuxDaemon/Pasted%20image%2020261014155926.png)
Navigating to the dashboard we can find alerts from `Auditd`. The rule description that starts with `Audit: ...` confirms it.
![Pasted image 20261014154233](assets/images/Task6-Audit-LinuxDaemon/Pasted%20image%2020261014154233.png)
View single document.
![Pasted image 20261014154806](assets/images/Task6-Audit-LinuxDaemon/Pasted%20image%2020261014154806.png)
Scroll.
![Pasted image 20261014154558](assets/images/Task6-Audit-LinuxDaemon/Pasted%20image%2020261014154558.png)
This is the full JSON format of the log.
```json
{
  "_index": "wazuh-alerts-4.x-2026.10.14",
  "_id": "1wZvOqEBkjY_zUhoICWY",
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
      "audit": {
        "syscall": "59",
        "gid": "0",
        "fsgid": "0",
        "session": "3",
        "pid": "15965",
        "suid": "0",
        "type": "SYSCALL",
        "uid": "0",
        "egid": "0",
        "exe": "/usr/bin/apt-config",
        "file": {
          "inode": "131489",
          "mode": "0100755",
          "name": "/usr/bin/apt-config"
        },
        "sgid": "0",
        "id": "747",
        "key": "audit-wazuh-c",
        "auid": "1000",
        "execve": {
          "argc": "4",
          "a1": "shell",
          "a2": "SourceList",
          "a3": "Dir::Etc::sourcelist",
          "a0": "apt-config"
        },
        "euid": "0",
        "command": "apt-config",
        "ppid": "15954",
        "fsuid": "0",
        "exit": "0",
        "cwd": "/tmp",
        "success": "yes",
        "tty": "pts2",
        "arch": "c000003e"
      }
    },
    "rule": {
      "firedtimes": 67,
      "mail": false,
      "level": 3,
      "description": "Audit: Command: /usr/bin/apt-config.",
      "groups": [
        "audit",
        "audit_command"
      ],
      "id": "80792",
      "gdpr": [
        "IV_30.1.g"
      ]
    },
    "decoder": {
      "parent": "auditd",
      "name": "auditd"
    },
    "full_log": "type=SYSCALL msg=audit(1791981719.606:747): arch=c000003e syscall=59 success=yes exit=0 a0=55700b558510 a1=55700b558450 a2=55700b558478 a3=30 items=2 ppid=15954 pid=15965 auid=1000 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=pts2 ses=3 comm=\"apt-config\" exe=\"/usr/bin/apt-config\" subj=unconfined key=\"audit-wazuh-c\"\u001dARCH=x86_64 SYSCALL=execve AUID=\"raneem\" UID=\"root\" GID=\"root\" EUID=\"root\" SUID=\"root\" FSUID=\"root\" EGID=\"root\" SGID=\"root\" FSGID=\"root\" type=EXECVE msg=audit(1791981719.606:747): argc=4 a0=\"apt-config\" a1=\"shell\" a2=\"SourceList\" a3=\"Dir::Etc::sourcelist\" type=CWD msg=audit(1791981719.606:747): cwd=\"/tmp\" type=PATH msg=audit(1791981719.606:747): item=0 name=\"/usr/bin/apt-config\" inode=131489 dev=08:02 mode=0100755 ouid=0 ogid=0 rdev=00:00 nametype=NORMAL cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0 cap_frootid=0\u001dOUID=\"root\" OGID=\"root\" type=PATH msg=audit(1791981719.606:747): item=1 name=\"/lib64/ld-linux-x86-64.so.2\" inode=133581 dev=08:02 mode=0100755 ouid=0 ogid=0 rdev=00:00 nametype=NORMAL cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0 cap_frootid=0\u001dOUID=\"root\" OGID=\"root\" type=PROCTITLE msg=audit(1791981719.606:747): proctitle=6170742D636F6E666967007368656C6C00536F757263654C697374004469723A3A4574633A3A736F757263656C697374",
    "input": {
      "type": "log"
    },
    "@timestamp": "2026-10-14T12:42:01.101Z",
    "location": "/var/log/audit/audit.log",
    "id": "1791981721.703703",
    "timestamp": "2026-10-14T15:42:01.101+0300"
  },
  "fields": {
    "timestamp": [
      "2026-10-14T12:42:01.101Z"
    ],
    "@timestamp": [
      "2026-10-14T12:42:01.101Z"
    ]
  }
}
```
#### Alert Summary

- "_source.audit.data.type": "SYSCALL"
- "_source.audit.data.uid": "0" (root)
- "_source.audit.data.exe": "/usr/bin/apt-config"

Which means thet a system call was invoked by `apt-config` executable.