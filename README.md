
```markdown
# SwarmFort

**TL;DR** — A batteries-included, security-hardened Docker Swarm platform that gives your team Kubernetes-grade security and observability without the operational complexity. One command to production: `make demo`.

[![CI](https://github.com/your-org/SwarmFort/actions/workflows/ci.yml/badge.svg)](https://github.com/your-org/SwarmFort/actions/workflows/ci.yml)
[![Security Scan](https://github.com/your-org/SwarmFort/actions/workflows/security-scan.yml/badge.svg)](https://github.com/your-org/SwarmFort/actions/workflows/security-scan.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![SLSA Level 2+](https://img.shields.io/badge/SLSA-Level%202%2B-brightgreen)](https://slsa.dev)

---

## 🧩 Why SwarmFort?

Small-to-medium engineering teams face a dilemma:

- **Kubernetes** is powerful but demands dedicated SRE resources and a steep learning curve.
- **Bare Docker Swarm** lacks encryption, supply chain security, and observability—it's not production-ready out of the box.

SwarmFort solves both problems. It's a **reference architecture** that layers enterprise-grade security and automation onto Docker Swarm—the orchestrator already built into Docker. No new tools to learn. No vendor lock-in. Just a secure, observable, and resilient platform that you can deploy in minutes.

> **Who is this for?** Teams of 5–50 engineers who want production-grade container infrastructure without hiring a dedicated SRE team. Ideal for startups, scale-ups, and on-premise deployments.

---

## 🏗️ Architecture at a Glance

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

**Key Design Decisions** (see [architecture.md](docs/architecture.md) for details):

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Orchestrator | Docker Swarm | Built-in, simpler, no etcd to manage |
| Ingress | Nginx | Mature, well-understood, custom config easy |
| Base Image | Alpine | < 25MB, minimal attack surface |
| Monitoring | Prometheus + Grafana + Loki | OSS, no vendor lock-in, Swarm-native service discovery |
| Log Aggregation | Fluentd → Loki | Lightweight, same stack as metrics |
| Security Policies | OPA/Rego | Policy-as-code, CI/CD enforceable |
| Supply Chain | Cosign + DCT + SLSA | Dual signing, verifiable provenance |
| GitOps | Ansible (primary) + Flux (optional) | Flexibility for different team preferences |

---

## ✨ Features & Security Rationale

### Why Every Security Layer Matters

| # | Layer | What It Prevents | Implementation |
|---|-------|-----------------|----------------|
| 1 | Encrypted Overlay (IPsec) | Eavesdropping on inter-node traffic | `--opt encrypted` on all networks |
| 2 | Network Isolation | Lateral movement; DB never exposed to internet | 3 separate overlay networks |
| 3 | Non-root User | Container escape → host compromise | `USER appuser` (UID 1001) |
| 4 | Capability Dropping | Privileged operations even as root | `cap_drop: ALL` |
| 5 | no-new-privileges | Privilege escalation via setuid | Set on every container |
| 6 | Read-only Rootfs | Binary/config tampering | Enabled on stateless services |
| 7 | Seccomp Profile | Dangerous syscall exploitation | Custom 300+ syscall whitelist |
| 8 | AppArmor Profile | Unauthorized file/network access | Mandatory access control |
| 9 | User Namespace Remap | Host root compromise via container | `userns-remap` in daemon |
| 10 | DCT + Cosign + SLSA | Unsigned/tampered images in registry | Dual signing + provenance |
| 11 | OPA Policies | Non-compliant deployments | Policy-as-code enforcement |
| 12 | Trivy (PR + Nightly) | CVEs in production | Block merge on HIGH/CRITICAL |
| 13 | Encrypted Backups | Data breach from backup theft | GPG symmetric encryption |
| 14 | Secret Rotation | Credential leaks | Automated rotation scripts |

---

## 🚀 Quick Start

### Prerequisites

| Requirement | Version | Check Command |
|-------------|---------|---------------|
| Terraform | ≥ 1.5 | `terraform version` |
| Azure CLI | Latest | `az version` |
| Docker | ≥ 24 | `docker version` |
| SSH Key | RSA 4096-bit | `ssh-keygen -t rsa -b 4096` |
| GitHub Account | - | For CI/CD |

### One-Command Deploy
```bash
git clone https://github.com/your-org/SwarmFort.git
cd SwarmFort
make demo
```
**What happens:** Terraform provisions 3 Azure VMs → Swarm initializes → TLS certs generated → Full stack deploys → Integration tests run → **Production-ready in ~10 minutes.**

### Verify Success
```bash
curl https://$(terraform -chdir=infra/terraform output -raw manager_public_ip)/health
# {"status":"ok"}
```

### Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| API | `https://<manager-ip>/health` | Public |
| Grafana | `http://<manager-ip>:3000` | admin/admin |
| Prometheus | `http://<manager-ip>:9090` | Public |
| Alertmanager | `http://<manager-ip>:9093` | Public |
| Loki (via Grafana) | `http://<manager-ip>:3100` | Explore in Grafana |

### Demo API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (returns `{"status":"ok"}`) |
| `/ping` | GET | Ping test (returns `{"message":"pong"}`) |
| `/metrics` | GET | Prometheus metrics |
| `/db-health` | GET | Database connectivity check |

---

## 🛠️ Makefile Reference

| Command | What It Does | When to Use |
|---------|-------------|--------------|
| `make demo` | Full deployment + tests | First time, demos |
| `make infra-up` | Create VMs + Swarm | Re-provisioning |
| `make deploy-stack` | Deploy/update stack | Code changes |
| `make test-all` | Structure + integration + chaos | Pre-release |
| `make scan` | Local Trivy scan | Pre-commit |
| `make backup` | Encrypted swarm backup | Before maintenance |
| `make restore` | Restore from backup | Disaster recovery |
| `make buildx` | Multi-arch build + push | Release |
| `make clean` | Destroy everything | Teardown |

---

## 🤖 CI/CD Pipeline

| Workflow | Trigger | What It Does |
|----------|---------|--------------|
| `ci.yml` | Pull Request | Build (amd64+arm64), Hadolint, Trivy (HIGH/CRITICAL), OPA/Conftest, Container Structure Test, SBOM |
| `security-scan.yml` | Nightly (2AM) | Full Trivy scan + Docker Bench Security audit |
| `release.yml` | Manual | Cosign + DCT sign, SLSA provenance, push, deploy |
| `multi-arch-builder.yml` | Manual | Verify cross-platform build |

---

## 🧪 Testing Strategy

| Test Type | Tool/Script | Coverage |
|-----------|------------|----------|
| Static Analysis | Hadolint | Dockerfile best practices |
| Vulnerability | Trivy | CVE detection (HIGH/CRITICAL) |
| Policy | OPA/Conftest | Image label + runtime config |
| Structure | Google Container Structure Tests | File, user, port, size |
| Integration | `test.sh` | API, DB, Redis, encryption |
| Chaos | `kill-random-node.sh` + `network-latency.sh` | Self-healing, resilience |

---

## 📊 Performance Benchmarks

| Metric | Value | Notes |
|--------|-------|-------|
| Image size (production) | 22.5 MB | Alpine base, multi-stage build |
| Image build time (CI) | ~6 minutes | Multi-arch (amd64+arm64) |
| Trivy scan time | ~2 minutes | Full scan |
| Swarm cluster creation | ~8 minutes | 3 Azure VMs |
| Stack deploy time | ~30 seconds | Rolling update |
| IPsec encryption overhead | 5-8% throughput | Measured on B2ats_v2 VMs |
| Backup size (empty stack) | ~500 KB | Encrypted tarball |

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| `make infra-up` fails | Check Azure credentials (`az login`), verify quota for B2ats_v2 in your region |
| `make deploy-stack` fails | Ensure `make setup-tls` ran first; check `docker service ls` for errors |
| Health check fails | Check if API container is running: `docker service ps swarmfort_api` |
| Grafana login fails | Default credentials are admin/admin; change via `GF_SECURITY_ADMIN_PASSWORD` env |
| Backup fails | Verify encryption key is set: `echo $BACKUP_ENCRYPTION_KEY` |
| Trivy scan exits with error | CVE threshold exceeded; review `trivy-results.sarif` artifact |

For more, see the full [Runbook](docs/runbook.md).

---

## 🌍 Multi-Language Support

SwarmFort is **language-agnostic**. Replace `app/` with your own application:

| Language | Dockerfile Example | Dependency File |
|----------|-------------------|-----------------|
| Python (default) | `Dockerfile` (FastAPI) | `requirements.txt` |
| Node.js | `FROM node:20-alpine` | `package.json` |
| Go | `FROM golang:1.21-alpine` | `go.mod` |
| Java | `FROM eclipse-temurin:17-jre-alpine` | `pom.xml` or `build.gradle` |

Only **two requirements**: a `/health` endpoint and a `Dockerfile` that follows the platform's security conventions. Everything else—networking, encryption, monitoring, CI/CD—remains unchanged.

---

## 🤝 Contributing

We welcome contributions! Please see:

- [CONTRIBUTING.md](CONTRIBUTING.md) — guidelines and workflow
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) — community standards
- [SECURITY.md](SECURITY.md) — vulnerability reporting

For major changes, open an issue first to discuss what you'd like to change.

---

## 📚 Full Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | Design decisions, diagrams, component map |
| [Security Hardening](docs/security-hardening.md) | Deep dive into every security feature |
| [Runbook](docs/runbook.md) | Operational procedures, alerts, recovery |
| [Trade-offs](docs/trade-offs.md) | Swarm vs K8s, Alpine vs distroless, etc. |

---

## 📜 License

MIT © SwarmFort Contributors. See [LICENSE](LICENSE).

---

## ⭐ Star History