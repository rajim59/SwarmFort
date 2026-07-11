# SwarmFort

**A production-grade Docker Swarm platform with zero‑trust security, supply chain integrity, and full observability — designed for teams that value simplicity over complexity.**

[![CI](https://github.com/Mehmed-Hasan-Rajim/SwarmFort/actions/workflows/ci.yml/badge.svg)](https://github.com/Mehmed-Hasan-Rajim/SwarmFort/actions/workflows/ci.yml)
[![Security Scan](https://github.com/Mehmed-Hasan-Rajim/SwarmFort/actions/workflows/security-scan.yml/badge.svg)](https://github.com/Mehmed-Hasan-Rajim/SwarmFort/actions/workflows/security-scan.yml)
[![SLSA Level 2+](https://img.shields.io/badge/SLSA-Level%202%2B-brightgreen)](https://slsa.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/mehmedhasanrajim/swarmfort-api)](https://hub.docker.com/r/mehmedhasanrajim/swarmfort-api)

---

## 🧩 The Problem

Small-to-medium engineering teams often need a container platform that is:
- **Simple** to operate without a dedicated SRE team
- **Secure** by default — encrypted traffic, signed images, hardened runtimes
- **Observable** with logs, metrics, and alerts
- **Resilient** with automated backups, rolling updates, and disaster recovery
- **Cost-effective** on commodity cloud VMs or on‑premise

Existing solutions force a choice between a minimal, insecure setup and a complex Kubernetes distribution that demands significant operational expertise. SwarmFort bridges this gap: it delivers enterprise‑grade security, monitoring, and automation on Docker Swarm — the orchestrator that’s already built into Docker.

---

## ✅ The Solution

SwarmFort is a **turnkey reference architecture** that transforms a vanilla Docker Swarm cluster into a hardened, production‑ready platform. It provides:

- 🔐 **Encrypted overlay networks** with automatic key rotation
- 🧱 **Three‑tier network isolation** (frontend, backend, database)
- 🚦 **Ingress TLS termination** via Nginx, with load balancing
- 🐳 **Golden base images** with non‑root users, updated SSL libraries, and custom CA bundles
- 🛡️ **Software supply chain security** – DCT, Cosign, SLSA provenance, SBOM generation
- ⚙️ **Runtime hardening** – seccomp, AppArmor, read‑only rootfs, no‑new‑privileges, user namespace remapping
- 📊 **Full observability** – Prometheus, Grafana dashboards (RED method + resource usage), Loki for logs, and Docker event streaming
- 🤖 **Automated operations** – encrypted swarm backup/restore, secret rotation, disk cleanup, cron jobs
- 🚀 **CI/CD pipelines** (GitHub Actions) for multi‑arch builds, vulnerability scanning, policy checks, and deployment
- 📈 **GitOps ready** – Ansible playbook and optional Flux configuration for declarative cluster management
- 🧪 **Chaos engineering tests** – random node kill and network latency injection to validate resilience

All of this is **fully automated** and driven by a single `Makefile`. From spinning up cloud VMs to deploying the entire stack and running integration tests, one command is enough: `make demo`.

---

## 🏗️ Architecture

![SwarmFort Architecture](docs/images/architecture.png)

### Network Isolation & Traffic Flow
```
                  ┌─────────────┐
                  │  INTERNET   │
                  └──────┬──────┘
                         │ :80, :443 (TLS)
                  ┌──────▼──────┐
                  │    Nginx    │  ← frontend-net (IPsec encrypted)
                  └──────┬──────┘
                         │
                  ┌──────▼──────┐
                  │     API     │  ← backend-net (IPsec encrypted)
                  └──┬───────┬──┘
                     │       │
           ┌─────────▼──┐ ┌──▼─────────┐
           │ PostgreSQL │ │   Redis    │  ← database-net (IPsec encrypted)
           └────────────┘ └────────────┘
```
- **Only Nginx exposes ports** to the internet (80/443). All other services communicate over encrypted overlay networks.
- **Monitoring services** (Prometheus, Grafana, Loki, cAdvisor, Node Exporter) run on a separate `monitoring-net` (also encrypted).

The complete component map and design decisions are documented in **[docs/architecture.md](docs/architecture.md)**.

---

## ✨ Feature Highlights & Rationale

### 🔐 Defense in Depth – Why Every Security Layer Matters
| Layer | Implementation | Why |
|-------|---------------|-----|
| **Encrypted overlay network** | `--opt encrypted` on all overlay networks | Prevents eavesdropping on inter‑node traffic; IPsec without extra infrastructure |
| **Network isolation** | `frontend-net`, `backend-net`, `database-net` | Limits blast radius; database never exposed to internet |
| **Golden base image** | `Dockerfile.base` with updated CA, libssl, non‑root user | Pre‑approved foundation for all app images; reduces CVE surface |
| **Non‑root user** | `USER appuser` (UID 1001) in all images | If container escapes, attacker has minimal privileges |
| **Capability dropping** | `cap_drop: ALL` in stack | Even root inside container has almost no kernel power |
| **no‑new‑privileges** | Set on every container | Prevents privilege escalation via setuid binaries |
| **Read‑only rootfs** | Enabled where possible | Attackers cannot modify binaries or configuration |
| **Seccomp profile** | Custom 300+ syscall whitelist | Blocks dangerous kernel calls; tailored for Python/Node APIs |
| **AppArmor profile** | Mandatory access control for app binaries | Restricts file, network, and capability access |
| **User namespace remapping** | `userns-remap` in daemon config | Maps container root to a high‑UID nobody on host |
| **DCT + Cosign + SLSA** | Offline root key, keyless signing, provenance | Verifiable supply chain; only signed images deployed |
| **OPA policies** | Image label + runtime config checks | Policy‑as‑code to enforce security standards before deployment |
| **Trivy scanning** | PR (HIGH/CRITICAL) + nightly full scan | Catch CVEs early; block merge if thresholds exceeded |
| **Encrypted backups** | GPG symmetric encryption | Backup theft doesn’t compromise data |

### 📊 Observability
- **Prometheus** scrapes cAdvisor, Node Exporter, and API `/metrics`.
- **Grafana dashboards** give instant visibility: API RED (Rate, Errors, Duration) and resource usage.
- **Loki** aggregates all container logs, enriched by Fluentd.
- **Alert rules** cover OOMKills, high latency, CPU/memory saturation, and disk exhaustion.
- **Docker event exporter** streams Swarm events into Loki for operational insight.

### ⚡ Operational Automation
- **Rolling updates** with `parallelism: 1`, `delay: 10s`, `failure_action: rollback`.
- **Canary deployment** script integrates with Prometheus to automate traffic shifting.
- **Encrypted swarm state backup** to local/S3; restorable with one command.
- **Secret rotation** renews credentials without downtime.
- **Overlay encryption key rotation** migrates services transparently.

---

## 🚀 Quick Start

### Prerequisites
- Azure CLI (or any cloud provider with Terraform)
- Terraform ≥ 1.5
- SSH key pair
- GitHub account (for CI/CD)

### 1. Clone the repository
```bash
git clone https://github.com/Mehmed-Hasan-Rajim/SwarmFort.git
cd SwarmFort
```

### 2. Deploy everything
```bash
make demo
```
This single command will:
1. Provision 3 Azure VMs (1 manager + 2 workers) with Docker pre‑installed.
2. Initialize a Docker Swarm and join workers.
3. Create encrypted overlay networks.
4. Set up TLS certificates and deploy the full stack (Nginx, API, PostgreSQL, Redis, monitoring).
5. Run integration tests to verify API, database, Redis, and network encryption.

### 3. Access the services
- **API:** `https://<manager-ip>/health`
- **Grafana:** `http://<manager-ip>:3000` (admin/admin)
- **Prometheus:** `http://<manager-ip>:9090`
- **Loki:** `http://<manager-ip>:3100`

---

## 🛠️ Using the Makefile

| Command | Description |
|---------|-------------|
| `make demo` | Full deployment from scratch + tests |
| `make infra-up` | Provision VMs and initialize Swarm |
| `make deploy-stack` | Deploy the application + monitoring stack |
| `make test-all` | Structure, integration, and chaos tests |
| `make scan` | Local Trivy vulnerability scan |
| `make backup` | Encrypted swarm state + volume backup |
| `make restore` | Restore from a backup (interactive) |
| `make buildx` | Build and push multi‑arch image |
| `make clean` | Remove stack and destroy infrastructure |

See `make help` for the full list.

---

## 🤖 CI/CD Automation

Everything is automated via GitHub Actions:

- **`ci.yml`** – Pull request: multi‑arch build, Hadolint, Trivy (HIGH/CRITICAL), OPA/Conftest, Container Structure Tests, SBOM.
- **`security-scan.yml`** – Nightly: full Trivy scan + Docker Bench Security audit.
- **`release.yml`** – Manual trigger: Cosign/DCT sign, SLSA provenance, push, deploy to Swarm.
- **`multi-arch-builder.yml`** – Verify cross‑platform builds.
- **`backup.yml`** – Scheduled encrypted backup of swarm state.

No manual intervention is needed for day‑2 operations.

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [Architecture](docs/architecture.md) | Design decisions, C4 diagrams, failure mode analysis |
| [Security Hardening](docs/security-hardening.md) | Every security layer implemented and justified |
| [Runbook](docs/runbook.md) | Day‑2 operations: deploy, rollback, backup/restore, alerts |
| [Trade‑offs](docs/trade-offs.md) | Architecture Decision Records with quantitative criteria |

---

## 🌍 Multi‑Language Support

The platform is language‑agnostic. The demo app is Python (FastAPI), but you can replace `app/` with:

| Language | Dockerfile Example | Dependency File |
|----------|-------------------|-----------------|
| Python (default) | `Dockerfile` (FastAPI) | `requirements.txt` |
| Node.js | `FROM node:20‑alpine` | `package.json` |
| Go | `FROM golang:1.21‑alpine` | `go.mod` |
| Java | `FROM eclipse‑temurin:17‑jre‑alpine` | `pom.xml` |

Only two requirements: a `/health` endpoint and a `Dockerfile` that respects the platform’s security conventions. Everything else—networking, encryption, monitoring, CI/CD—stays the same.

---

## 🧪 Testing

| Test Type | Tool / Script | Coverage |
|-----------|---------------|----------|
| Static Analysis | Hadolint | Dockerfile best practices |
| Vulnerability | Trivy | CVE detection (HIGH/CRITICAL) |
| Policy | OPA/Conftest | Image labels + runtime config |
| Structure | Google Container Structure Tests | File, user, port, image size |
| Integration | `test.sh` | API, DB, Redis, encryption |
| Chaos | `kill-random-node.sh`, `network-latency.sh` | Self‑healing, resilience |

Run `make test-all` to execute the complete suite.

---

## 🧑‍💻 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community standards.

---

## 📜 License

This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.

---