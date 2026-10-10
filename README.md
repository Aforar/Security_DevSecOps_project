# Open-Source WAF-Based Web Application Security Solution

A containerized Web Application Firewall (WAF) lab using Nginx,
ModSecurity, OWASP Core Rule Set (CRS), and DVWA to demonstrate
web request inspection and blocking of selected attack patterns.

## Project Overview

This project deploys a WAF in front of a deliberately vulnerable
web application. ModSecurity and OWASP CRS inspect incoming HTTP
requests and can block requests that match configured security rules.

The lab demonstrates:

- Containerized deployment with Docker Compose
- Nginx integration with ModSecurity
- OWASP CRS rule-based request inspection
- Configurable paranoia and anomaly-score thresholds
- Basic validation of SQL injection, XSS, and path traversal payloads
- Container health checks and validation reports

## Architecture

```text
Client / curl
     |
     | HTTP :8080
     v
Nginx + ModSecurity + OWASP CRS
     |
     | Docker network
     v
DVWA backend :80
```

The WAF is exposed on host port `8080`. DVWA is available internally
to the WAF through the Docker network.

## Technology Stack

| Component | Version / Configuration |
|---|---|
| Container orchestration | Docker Compose |
| WAF web server | Nginx |
| WAF engine | ModSecurity |
| ModSecurity Nginx connector | 1.0.4 |
| OWASP Core Rule Set | 4.30.0 |
| Loaded CRS rules | Approximately 856 |
| Vulnerable test application | DVWA |
| Backend URL | `http://dvwa:80` |

The ModSecurity library version reported by the running container is
`3.0.17`.

## Configuration

The WAF service uses the following environment settings:

| Setting | Value | Purpose |
|---|---:|---|
| `BACKEND` | `http://dvwa:80` | Upstream application |
| `DETECTION_PARANOIA` | `2` | Detection paranoia level |
| `BLOCKING_PARANOIA` | `2` | Blocking paranoia level |
| `ANOMALY_INBOUND` | `5` | Inbound anomaly-score threshold |
| `ANOMALY_OUTBOUND` | `4` | Outbound anomaly-score threshold |

The Nginx configuration template is mounted from:

`./nginx/default.conf.template`

The WAF container is named `waf-nginx`, and the application container
is named `dvwa`.

## Prerequisites

- Linux environment
- Docker Engine
- Docker Compose plugin
- Terminal access
- Basic familiarity with HTTP and command-line tools

## Run the Lab

From the project directory:

```bash
docker compose config --quiet
docker compose up -d
docker ps
```

Open the application through the WAF:

`http://localhost:8080`

To inspect container logs:

```bash
docker logs waf-nginx
docker logs dvwa
```

To check the WAF health status:

```bash
docker inspect waf-nginx \
  --format '{{.State.Health.Status}}'
```

To stop the lab without explicitly deleting named volumes:

```bash
docker compose down
```

Do not use `docker compose down -v` unless you intentionally want to
remove the Compose-managed volumes.

## Validation

The final validation was run on **2026-10-10**.

| Check | Expected result | Observed result |
|---|---|---|
| Docker Compose configuration | Valid | PASS |
| `ANOMALY_OUTBOUND` configuration | `4` | PASS |
| WAF container | Running | PASS |
| DVWA container | Running | PASS |
| WAF health check | Healthy | PASS |
| ModSecurity engine | Enabled | PASS |
| Benign request to `/` | HTTP 302 | PASS |
| SQL injection test request | HTTP 403 | PASS |
| XSS test request | HTTP 403 | PASS |
| Path traversal test request | HTTP 403 | PASS |

**Final validation summary: 10 PASS, 0 FAIL.**

The benign request returns `302`, indicating that the application
responds with a redirect. The attack-test requests return `403`,
indicating that the WAF blocks those specific requests under the
tested configuration.

### Reproduce the HTTP Tests

Run these commands from the machine hosting the containers.

Benign request:

```bash
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' \
  http://localhost:8080/
```

SQL injection test:

```bash
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' \
  --get --data-urlencode 'id=1 OR 1=1' \
  http://localhost:8080/
```

XSS test:

```bash
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' \
  --get --data-urlencode 'q=<script>alert(1)</script>' \
  http://localhost:8080/
```

Path traversal test:

```bash
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' \
  --get --data-urlencode 'file=../../../../etc/passwd' \
  http://localhost:8080/
```

These payloads are test inputs for the local lab. The expected responses
are `302` for the benign request and `403` for the three attack tests.

## Validation Reports

Validation output is stored under the `reports/` directory.

The final validation report generated during this lab was:

`reports/final-validation-20261010-180915.txt`

The project also contains a validation script under `scripts/`.

Review logs and reports before publishing them. Remove session cookies,
credentials, tokens, sensitive request data, and environment-specific
details if present.

## Security Considerations and Limitations

- DVWA is deliberately vulnerable and must only be used in an isolated,
  authorized lab environment.
- The host port `8080` should not be exposed publicly without an
  appropriate security review.
- HTTP status codes from a small set of payload tests do not establish
  comprehensive protection against all attack variants.
- A `403` confirms rejection of the tested request, not that every
  possible exploit is blocked.
- A `302` confirms a redirect response; it does not establish that every
  application feature works correctly.
- False positives, application-specific exclusions, logging, TLS,
  deployment hardening, and broader regression testing require separate
  evaluation.
- Do not disable CRS rules or weaken anomaly thresholds just to make a
  test pass. Investigate false positives in the context of a specific,
  legitimate application endpoint.

## Skills Demonstrated

- Docker and Docker Compose
- Linux command-line administration
- Nginx reverse-proxy configuration
- ModSecurity and OWASP CRS integration
- HTTP request testing with curl
- Security event and container-log inspection
- Health checks and repeatable validation
- Technical documentation and test reporting

## Disclaimer

This repository describes a learning and portfolio lab. It is not a
claim of certification, a full penetration test, or a guarantee that
an application is secure. Test only systems you own or are explicitly
authorized to assess.
