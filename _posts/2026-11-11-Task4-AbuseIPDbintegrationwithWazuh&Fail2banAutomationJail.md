---
title: AbuseIPDb Integration with Wazuh & Fail2ban Automation Jail
date: 2026-11-11
categories: Lab SOC
tags: threat-intelligence ids edr
toc: true
mermaid: true
share: true
slug: 2026-11-11-Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail
attachment:
  send: true
  folder: assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail
---

AbuseIPDb is a project for reporting IPs associated with malicious activity, which records every IP address's reports and keeps a reputation score of it based on that.
To automate IP checks and blocking malicious ones, we integrate AbuseIPDb with wazuh using `fail2ban` tool with its jail feature, alongside the API key provided to my AbuseIPDb account, the API type is REST over HTTP.
Before we dive in, let's talk about what a jail is, it's a kind of defensive measure that affects a specific service running on an endpoint (e.g. SSH server) and based on the jail configurations, if a threshold is met then the action is triggered and an IP will be blocked or reported for example.
## Lab setup
This is the current lab setup from previous SOC lab posts up till now.
![Pasted image 20261111230202](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261111230202.png)
## `fail2ban` Installation on Ubuntu
https://github.com/fail2ban/fail2ban/wiki/How-to-install-fail2ban-packages#debian--ubuntu
Install with a simple command.
![Pasted image 20261007134605](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007134605.png)
## `fail2ban` Configuration
### Steps
To configure `fail2ban` tool we use the `fail2ban` client that comes with it, to check wither it supports AbuseIPDb we look at the version and check if `/etc/fail2ban/action.d/abuseipdb.conf` exists.
![Pasted image 20261007140257](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007140257.png)
Additionally, We will use `/etc/fail2ban/jail.local` file to specify our required configurations instead of modifying `/etc/fail2ban/jail.conf` directly and they will override the default configs in `jail.conf`, this is how the service configurations are setup to avoid it being reset in package updates.
So, let's create `/etc/fail2ban/jail.local` and paste the basic configs from the docs page: https://www.digitalocean.com/community/tutorials/how-to-protect-ssh-with-fail2ban-on-centos-7#configure-local-settings

> This overrides three settings: It sets a new default `bantime` for all services, makes sure we’re using `iptables` for firewall configuration, and enables the `sshd` jail. - docs page link above

![Pasted image 20261007142431](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007142431.png)
Restart to apply the new configurations.
![Pasted image 20261007143019](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007143019.png)
### Troubleshooting `fail2ban`
After restart it failed, so I went to search what in my configurations in `jal.local` caused it. 
![Pasted image 20261007144333](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007144333.png)
After searching, I found out that setting the action to use `iptables` while it is not a tool installed on my machine.
So I remove this line from `jail.local`.
```
banaction = iptables-multiport
```

![Pasted image 20261007143937](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007143937.png)
Restart.
![Pasted image 20261007145244](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007145244.png)
However, the issue persists, so I went back and realized `/etc/fail2ban/jail.local` has to have the whole block of a section that I want to override its configurations copied from `/etc/fail2ban/jail.conf`.
So let's copy this section:
```
[sshd]

# To use more aggressive sshd modes set filter parameter "mode" in jail.local:
# normal (default), ddos, extra or aggressive (combines all).
# See "tests/files/logs/sshd" or "filter.d/sshd.conf" for usage example and details.
#mode   = normal
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
```
To `jail.local` and add the line:
```
enabled = true
```

![Pasted image 20261007152619](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007152619.png)
And finally it worked out, the custom SSH jail configurations were applied and the service is running.
![Pasted image 20261007152801](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007152801.png)
### `fail2ban` action configuration: ban and report an IP
Let's see more detailed information about SSH jail.
![Pasted image 20261007152933](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007152933.png)
There are information about banned IPs and failure records and such.
Next Let's make sure action definition code exists in `/etc/fail2ban/jail.conf`.
![Pasted image 20261007153600](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007153600.png)
It is here and the service supports the AbuseIPDB Fail2Ban action.
Now let's add an action to our SSH jail that will ban and report an IP for specifically SSH brute-force attack. Also my API key must go in this action definition line.
![Pasted image 20261007154615](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007154615.png)
Restart, reload and check status, shows success of configurations.
![Pasted image 20261007155025](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007155025.png)
Also adding a general action in the `[DEFAULT]` section of configuration file `jail.local` will report an IP without specifying a jail.
```
# Choose default action.  To change, just override value of 'action' with the
# interpolation to the chosen action shortcut (e.g.  action_mw, action_mwl, etc) in jail.local
# globally (section [DEFAULT]) or per specific section
action = %(action_)s
         **%(action_abuseipdb)s[abuseipdb_apikey="my-api-key", abuseipdb_category="18"]**
```
Added the above block of code to the end of `[DEFAULT]` section that I copied from `/etc/fail2ban/jail.conf`. This allows for reporting every IP that was caught doing malicouos activity on our intrusion detection system (Wazuh).  
![Pasted image 20261009164015](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261009164015.png)
Restart service and reload.
![Pasted image 20261009163043](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261009163043.png)
## Integration with Wazuh
https://wazuh.com/blog/detecting-known-bad-actors-with-wazuh-and-abuseipdb/
### Define Custom Rules
To start off, the file `/var/ossec/etc/rules/local_rules.xml` is designed to contain user custom rules, to avoid package upgrades from removing them; they are saved separately from default rules.
So let's edit it. Adding two rules with IDs 100002 and 100003 and by regex matching using `perl` language for matching all possible public IP addresses. Furthermore, the `<if-sid>` tag tells the Wazuh engine to check my custom rule only if an event's rule ID has matched the specified within this tag. This means I'm referencing a Wazuh internal rule and if applied to an event then my rule will also apply, just like parent-child process logic.
![Pasted image 20261007155846](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007155846.png)
Also verify that `perl` is installed for regex matching to work.
![Pasted image 20261007233631](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261007233631.png)
### Integration: setup and automation
Define integration block in `/var/ossec/etc/ossec.conf` file and insert the API key here.
![Pasted image 20261009183330](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261009183330.png)
Next create a file called `custom-abuseipdb.py` in `/var/ossec/integrations/`, and get the script from https://wazuh.com/blog/detecting-known-bad-actors-with-wazuh-and-abuseipdb/ to insert there.
This script is what basically sends the request from Wazuh to AbuseIPDb along with its parameters (e.g. API key, IP address).
![Screenshot (401)](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Screenshot%20(401).png)
Change permissions to allow the script to run as required.
![Pasted image 20261008004712](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008004712.png)
Restart the service to apply the new configurations.
![Pasted image 20261008004915](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008004915.png)
### Enrich alerts with information fields
Back to custom rules file in `/var/ossec/etc/rules/local_rules.xml`, We can add a rule that reference another custom rule to include more details about the reported IP in the alert. The following rules add a confidence score field to both failed and succeeded SSH authentication event/alert.
![Pasted image 20261008010031](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008010031.png)
Restart to apply new configurations. It is running as expected and this marks the success of AbuseIPDb integration with Wazuh. 
![Pasted image 20261008010950](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008010950.png)
## Testing
### Steps
First create a test log file.
Then add it to `/var/ossec/etc/ossec.conf` so that Wazuh agent monitors it.
```
<localfile>
<log_format>syslog</log_format>
<location>/var/log/test.log</location>
</localfile>
```

![Screenshot (406) cp](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Screenshot%20(406)%20cp.png)
Then restart the agent and check its status.
![Pasted image 20261008012527](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008012527.png)
To test it, we need a log line that triggers the jail so we inject it into the `test.log`, it basically says that a malicious IP had a failed login attempt.
![Screenshot (408)](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Screenshot%20(408).png)
And from the dashboard, it shows the alert was generated successfully.
![Pasted image 20261008015115](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008015115.png)
And this is an alert JSON, which shows the `rule.id` and `rule.groups` to have the configured fields from our custom rules in `/var/ossec/etc/rules/local_rules.xml`. 
```json
{
  "_index": "wazuh-alerts-4.x-2026.10.07",
  "_id": "VIeJGKEBs9a_UfQFD5As",
  "_score": 1,
  "_source": {
    "agent": {
      "ip": "10.10.10.9",
      "name": "raneem-agent-1",
      "id": "001"
    },
    "data": {
      "srcip": "64.62.197.132",
      "dstuser": "root",
      "srcport": "1066"
    },
    "rule": {
      "firedtimes": 2,
      "mail": false,
      "level": 5,
      "pci_dss": [
        "10.2.4",
        "10.2.5"
      ],
      "description": "sshd: Authentication succeeded from a public IP address 64.62.197.132.",
      "groups": [
        "local",
        "syslog",
        "sshd",
        "authentication_failed",
        "authentication_success"
      ],
      "id": "100003"
    },
    "full_log": "Dec 10 01:02:02 host sshd[1234]: Accepted none for root from 64.62.197.132 port 1066 ssh2",
    "id": "1791412993.54358",
    "timestamp": "2026-10-08T01:43:13.695+0300",
    "predecoder": {
      "hostname": "host",
      "program_name": "sshd",
      "timestamp": "Dec 10 01:02:02"
    },
    "manager": {
      "name": "raneem-VMware-Virtual-Platform"
    },
    "decoder": {
      "parent": "sshd",
      "name": "sshd"
    },
    "input": {
      "type": "log"
    },
    "@timestamp": "2026-10-07T22:43:13.695Z",
    "location": "/var/log/test.log",
    "GeoLocation": {
      "country_name": "United States",
      "location": {
        "lon": -97.822,
        "lat": 37.751
      }
    }
  },
  "fields": {
    "timestamp": [
      "2026-10-07T22:43:13.695Z"
    ],
    "@timestamp": [
      "2026-10-07T22:43:13.695Z"
    ]
  }
}
```
#### Alert Summary
Key values:
- "description": "sshd: Authentication succeeded from a public IP address 64.62.197.132."
- "timestamp":"2026-10-07T22:43:13.695Z"
### Troubleshooting
I have yet to verify that custom rules (IDs 100004 and 100005) are also included but they aren't shown, in the dashboard, so I realized I had not configured one more thing in the manager's configurations in `/var/ossec/etc/ossec.conf` , which is to set `<logall>` tag value to `yes`.
![Pasted image 20261008024127](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008024127.png)
And then restart.
![Pasted image 20261008024541](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008024541.png)
### Retest
#### Endpoint Monitoring
Redo the same steps from testing in earlier section.
![Pasted image 20261008025021](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008025021.png)
Again I had to go back to `/var/ossec/etc.ossec.conf` and correct a syntax mistake. And Then it finally succeeded. The events show rule ID 100005 with its enrichment information.
![Pasted image 20261008030414](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008030414.png)
Also, shown in the alerts.
![Pasted image 20261008030824](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261008030824.png)
This is one alert of rule ID 100005 in JSON format:
```json
{
  "_index": "wazuh-alerts-4.x-2026.10.08",
  "_id": "6ofRGKEBs9a_UfQFPJCg",
  "_score": null,
  "_source": {
    "input": {
      "type": "log"
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
      "abuseipdb": {
        "country_code": "US",
        "last_reported_at": "2026-10-07T09:30:24+00:00",
        "found": "1",
        "total_reports": "1702",
        "usage_type": "Fixed Line ISP",
        "isp": "The Shadowserver Foundation, Inc.",
        "domain": "shadowserver.org",
        "abuse_confidence_score": "100",
        "source": {
          "srcip": "64.62.197.132",
          "alert_id": "1791417708.107761",
          "rule": "100003",
          "description": "sshd: Authentication succeeded from a public IP address 64.62.197.132.",
          "full_log": "Dec 10 01:02:02 host sshd[1234]: Accepted none for root from 64.62.197.132 port 1066 ssh2"
        }
      },
      "integration": "custom-abuseipdb"
    },
    "rule": {
      "firedtimes": 6,
      "mail": true,
      "level": 14,
      "pci_dss": [
        "10.2.4",
        "10.2.5"
      ],
      "description": "AbuseIPDB: SSH Authentication succeeded from a public IP address 64.62.197.132 with 100% confidence of abuse.",
      "groups": [
        "local",
        "syslog",
        "sshd",
        "authentication_failed"
      ],
      "id": "100005"
    },
    "location": "abuseipdb",
    "decoder": {
      "name": "json"
    },
    "id": "1791417725.111252",
    "full_log": "{\"abuseipdb\": {\"found\": 1, \"source\": {\"alert_id\": \"1791417708.107761\", \"rule\": \"100003\", \"description\": \"sshd: Authentication succeeded from a public IP address 64.62.197.132.\", \"full_log\": \"Dec 10 01:02:02 host sshd[1234]: Accepted none for root from 64.62.197.132 port 1066 ssh2\", \"srcip\": \"64.62.197.132\"}, \"abuse_confidence_score\": 100, \"country_code\": \"US\", \"usage_type\": \"Fixed Line ISP\", \"isp\": \"The Shadowserver Foundation, Inc.\", \"domain\": \"shadowserver.org\", \"total_reports\": 1702, \"last_reported_at\": \"2026-10-07T09:30:24+00:00\"}, \"integration\": \"custom-abuseipdb\"}",
    "timestamp": "2026-10-08T03:02:05.429+0300"
  },
  "fields": {
    "timestamp": [
      "2026-10-08T00:02:05.429Z"
    ]
  },
  "sort": [
    1791417725429
  ]
}
```
It shows detailed information in the `_score.data` section.
#### Wazuh Manager: Server Monitoring
Add `test.log` to monitored files in `ossec.conf`
![Pasted image 20261009160513](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261009160513.png)
We do the injector method now.
![Pasted image 20261009185121](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261009185121.png)
And alerts appear in the dashboard now by filtering based on rule IDs.
![Screenshot (424)](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Screenshot%20(424).png)
##### Ban an IP
It is also reported automatically.
![Pasted image 20261009185759](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261009185759.png)
Shown in blacklist after it was banned.
![Pasted image 20261009185820](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261009185820.png)
We can also confirm it from the logs.
![Pasted image 20261009190017](assets/images/Task4-AbuseIPDbintegrationwithWazuh&Fail2banAutomationJail/Pasted%20image%2020261009190017.png)
##### Trigger report and ban by SSH brute-force attack 
