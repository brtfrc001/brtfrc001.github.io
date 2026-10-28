---
title: "Malware Information Sharing Platform Integration with Wazuh Tutorial"
categories: Lab
tags:
  - SOC Analyst
  - IDS
  - Threat Intelligence
  - Malware
  - Tutorial
toc: true
mermaid: true
---

**MISP Intelligence Sharing Platform** (MISP) is an open-source software for sharing threat intelligence, integrating it into SIEM solution provides enrichment data about malware and all threat intelligence types by automatically correlating IoCs (Indicator of Compromise) that are detected with other documented IoCs in MISP database.

In MISP every **IoC** is associated with an **event ID**, for example a well-known malware sample named [WannaCry](https://www.misp-project.org/galaxy.html#_wannacry) has event ID: 42, and an event's **attribute** is the actual IoC (e.g., a malicious IP, domain name, file hash, etc.).

An **event** is a context which is distinct by its **attributes**, these which get compared against other events' attributes to match an event from threat intelligence database MISP, this is essentially what **correlation engine** of MISP software does. 

Furthermore an attribute can be excluded from this comparison if it generates too much noise by setting the **correlation flag** to be disabled. The flag exists for every attribute, also **correlation rules** can be utilized for more advanced tuning.
## Setup
In a third virtual machine we'll install docker engine, so that MISP software will run as a container on top of it.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261028225445.png)

## Installation
### Prerequisites
- Docker must be installed.
- Access to pull container images from `ghcr.io`.
- Access to Docker Hub for pulling base images and dependencies.
### Steps
I installed Docker engine and docker compose plugin. As well as setting up my PATs from GitHub and Docker Hub. Shown in the screenshot the docker components versions and success message of my tokens setup.  

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261012151152.png)

Copying the `template.env` to `.env` in my working directory.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261012154544.png)

Next we pull pre-built images from Docker Hub by running the command:
```
docker compose pull
```
Download successfully finished.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261012154906.png)

To run the service:
```
docker compose up
```
It is running.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261012155611.png)

I can see the GUI on my browser now.
Default credentials:
- User: `admin@admin.test`
- Password: `admin`
To be changed.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261012155916.png)

This is the events page.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261012160045.png)

Changed the admin password.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261013202251.png)

## Integration with Wazuh
### Setup
I repeated the same steps on the machine of Wazuh server to install MISP software on it, shown below the web login interface.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261013230445.png)

This is the updated lab setup with all previous tasks set up.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261013225133.png)

### Steps
Copy `custom-misp-file-hash.py` from the tutorial https://www.misp-project.org/2025/10/06/wazuh-integration.html/ and place in `/var/ossec/integrations/` directory, and change its permissions.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261013201434.png)

So, I made a new user and an organization to get an API key.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261013234216.png)

This my organazation page.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261013234727.png)

Let's add an auth key.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261013234918.png)

Add `<integration>` block to the `/var/ossec/etc/ossec.conf`, and add my MISP user API AuthKey.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261013235436.png)

Then I restart the service.
Next I added this line to troubleshoot services ports conflict, and binds docker's container to `8443`.
```
NGINX_HTTPS_PORT=8443
```
And then restart MISP docker.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261014003335.png)

Looking at the two web interfaces, there's no issue anymore.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261014003446.png)

Next, add new rules file for MISP via web interface.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261014003751.png)

Then restart the manger.
## Troubleshooting
### Make a self-signed certificate
This shows that there isn't a SSL certificate to begin with, and to run MISP web interface on HTTPS we need one.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261020175445.png)

According to official docs, I have to create SSL certificate, which I didn't and that's why it was failing and giving errors like in the image below in the logs. It appears because I added a line that specifies URL for HTTPS connection, and before I specified the port for which it should use which is non-default one `8443` and that seems to me the reason I have to configure the certificate manually. Either that or it wasn't an automated thing in the installation from the start.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261020174946.png)

Create a certificate.
```
mkdir -p ./ssl/ && openssl req -x509 -subj '/CN=localhost' -nodes -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -addext "subjectAltName = DNS:localhost, IP:127.0.0.1, IP:::1"
```
And then change the certificate files' permissions.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261020181101.png)

The `key.pem` is confidential though so I transfer ownership to `www-data` user.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261020182004.png)

Finally, it is working using HTTPS.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261020182414.png)

Showing the port details below.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261020182535.png)

### Trusting the self-signed certificate
The integration script didn't run, according to the web requests log generated from the `misp-docker-misp-nginx-1` container, I concluded this because the expected behavior is that a `HTTPS` request is sent when I trigger the MISP rule. Showing below only `HTTP GET` request is sent for health check. 

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261021161441.png)

However, it is more accurate to say it ran but the request wasn't successful, the cause is shown below from `/var/ossec/logs/ossec.log` which is SSL certificate stored on my host wasn't accessible to python binary that runs wazuh's integrations located at `/var/ossec/framework/python/bin/python3` and it doesn't see the certificate as a trust worthiness certificate.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261021155246.png)

It was told (Gemini) that this is not a production environment solution, as it introduce vulnerabilities related to python environment scale and integration scripts privilege, also the certificate will be accessible to all other integrations which it poses associated risks, but since we're on an isolated home lab, I will continue. Shown below, the certificate `~/misp-docker/ssl/cert.pem` is appended to `certifi` module, which is a collection of certificates provided by Mozilla for trusting them and enabling us to use SSL requests and verify certificates in our python environment.
This is a very rich topic but this is my simplified description of what's going on.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261021161915.png)

Also I could use the edit code in `/etc/ossec/integrations/custom-misp-file-hashes.py`.
```
MISP_CA_BUNDLE = f"{pwd}/etc/certs/misp-ca.pem"
```
And this code block to edit `verify` variable.
```
response = requests.post(
    f"{misp_url}/attributes/restSearch",
    json=rest_search_payload,
    headers=headers,
    timeout=timeout,
    verify=MISP_CA_BUNDLE,
)
```
Apparently this is the standard verification way, because the previous way will not work when `certifi` module is updated, but I can still just append the certificate again.
However, when I tried to modify the integration script, it didn't allow me to.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261021165722.png)

This is the error it says, although it wasn't a syntax error, but the script is made this way.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261021170023.png)

Anyways I revert to method 1 and it works just fine in the next section "Testing".
## Testing
After endless tries and debugging loops, here's the test triggering the MISP rule by installing a malware on the monitored directory on `raneem-agent-1` endpoint.

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261021170353.png)

And here's the moment you have been waiting for (I have).

![](/assets/images/lab/misp-integration-with-wazuh/Pasted%20image%2020261021170546.png)

Full JSON of the alert.
```json
{
  "_index": "wazuh-alerts-4.x-2026.10.21",
  "_id": "jwa-XqEBkjY_zUhoT3Nc",
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
      "integration": "misp_file_hashes",
      "misp_file_hashes": {
        "found": "1",
        "source": {
          "sha1": "3395856ce81f2b7382dee72602f798b642f14140",
          "file": "/media/user/software/malicious-file.exe",
          "sha256": "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f",
          "alert_id": "1792590887.18642472",
          "md5": "44d88612fea8a8f36de82e1278abb02f"
        },
        "type": "md5",
        "event_uuid": "b174055e-3b79-4339-b641-392c08663052",
        "permalink": "https://127.0.0.1:8443/events/view/b174055e-3b79-4339-b641-392c08663052/searchFor:995b5b6e-016d-49b7-9f08-dc048275ccde",
        "value": "44d88612fea8a8f36de82e1278abb02f",
        "uuid": "995b5b6e-016d-49b7-9f08-dc048275ccde",
        "timestamp": "1791932106"
      }
    },
    "rule": {
      "firedtimes": 1,
      "mail": true,
      "level": 12,
      "description": "MISP: file hash matched",
      "groups": [
        "misp",
        "malware"
      ],
      "id": "100802"
    },
    "decoder": {
      "name": "json"
    },
    "full_log": "{\"misp_file_hashes\": {\"found\": 1, \"source\": {\"alert_id\": \"1792590887.18642472\", \"file\": \"/media/user/software/malicious-file.exe\", \"md5\": \"44d88612fea8a8f36de82e1278abb02f\", \"sha1\": \"3395856ce81f2b7382dee72602f798b642f14140\", \"sha256\": \"275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f\"}, \"type\": \"md5\", \"value\": \"44d88612fea8a8f36de82e1278abb02f\", \"uuid\": \"995b5b6e-016d-49b7-9f08-dc048275ccde\", \"timestamp\": \"1791932106\", \"event_uuid\": \"b174055e-3b79-4339-b641-392c08663052\", \"permalink\": \"https://127.0.0.1:8443/events/view/b174055e-3b79-4339-b641-392c08663052/searchFor:995b5b6e-016d-49b7-9f08-dc048275ccde\"}, \"integration\": \"misp_file_hashes\"}",
    "input": {
      "type": "log"
    },
    "@timestamp": "2026-10-21T13:54:50.389Z",
    "location": "misp_file_hashes",
    "id": "1792590890.18652705",
    "timestamp": "2026-10-21T16:54:50.389+0300"
  },
  "fields": {
    "timestamp": [
      "2026-10-21T13:54:50.389Z"
    ],
    "@timestamp": [
      "2026-10-21T13:54:50.389Z"
    ]
  }
}
```
By the way, this is how the request looks like from the `misp-docker-misp-nginx-1` container logs.
```
root@raneem-VMware-Virtual-Platform:~/misp-docker# docker logs -f misp-docker-misp-nginx-1
[redact]
172.18.0.1 - - [21/Oct/2026:13:54:50 +0000] "POST /attributes/restSearch HTTP/1.1" 200 867 "-" "Python library-client-Wazuh-MISP" "-"
172.18.0.1 - - [21/Oct/2026:13:54:50 +0000] "POST /sightings/add HTTP/1.1" 200 265 "-" "Python library-client-Wazuh-MISP" "-"
```
## Plus
- This is the python binary that Wazuh integration scripts use.
```
/var/ossec/framework/python/bin/python3
```
- In the following command, `integratord` which is daemon for enabling integrations and running their scripts, that's why we refer to it in troubleshooting.
```
root@raneem-VMware-Virtual-Platform:~/misp-docker# grep wazuh-integratord /var/ossec/logs/ossec.log | tail -n 20
```
