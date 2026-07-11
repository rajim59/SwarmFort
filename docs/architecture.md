# SwarmFort Architecture

**A production-grade Docker Swarm platform — C4 Model, design decisions, failure mode analysis, and capacity planning.**

---

## 1. Overview

SwarmFort transforms a vanilla Docker Swarm cluster into a hardened, observable, and automated application platform. It is designed for teams that need enterprise-grade infrastructure without the operational burden of Kubernetes.

### Design Goals
- **Security by default**: Defense-in-depth at every layer—network, runtime, supply chain.
- **Simplicity**: Single-command deployment (`make demo`), no external orchestrator dependencies.
- **Observability**: Metrics, logs, and alerts integrated into the platform, not bolted on.
- **Resilience**: Automated backups, rolling updates, and self-healing via Swarm’s native scheduler.
- **Language-agnostic**: The platform is independent of any specific application language or framework.

---

## 2. C4 Model

### 2.1 System Context (Level 1)

```mermaid
graph TB
    User[👤 Developer / End User]
    Internet[🌐 Internet]
    GitHub[🐙 GitHub Actions]
    DockerHub[📦 Docker Registry]
    SwarmFort[🛡️ SwarmFort Platform]
    S3[☁️ S3 / Object Storage]

    User -->|HTTPS| Internet
    GitHub -->|CI/CD Triggers| DockerHub
    GitHub -->|Deploy| SwarmFort
    Internet -->|TLS :443| SwarmFort
    SwarmFort -->|Backup| S3
    DockerHub -->|Pull Images| SwarmFort
```

**External Systems:**
- **Developer / End User** — Accesses the API via HTTPS.
- **GitHub Actions** — CI/CD pipeline; builds, scans, signs, and deploys images.
- **Docker Registry** — Stores signed, multi-arch images.
- **S3 / Object Storage** — Stores encrypted backups.

### 2.2 Container Diagram (Level 2)

```mermaid
graph TB
    subgraph "SwarmFort Platform"
        subgraph "Frontend Tier (frontend-net)"
            Nginx[🐺 Nginx<br/>TLS Termination<br/>Load Balancer]
        end

        subgraph "Application Tier (backend-net)"
            API[🐍 API<br/>FastAPI<br/>3 replicas]
        end

        subgraph "Data Tier (database-net)"
            DB[🐘 PostgreSQL<br/>1 replica]
            Redis[🔴 Redis<br/>1 replica]
        end

        subgraph "Monitoring Tier (monitoring-net)"
            Prom[📊 Prometheus]
            Grafana[📈 Grafana]
            Loki[📜 Loki]
            cAdvisor[📦 cAdvisor]
            NodeExp[🖥️ Node Exporter]
            Fluentd[📝 Fluentd]
        end
    end

    Internet[🌐 Internet] -->|HTTPS| Nginx
    Nginx -->|Proxy| API
    API -->|SQL| DB
    API -->|Cache| Redis
    API -->|Metrics| Prom
    Prom -->|Dashboards| Grafana
    Fluentd -->|Logs| Loki
    cAdvisor -->|Container Metrics| Prom
    NodeExp -->|Host Metrics| Prom
```

### 2.3 Deployment Diagram (Node Distribution)

```mermaid
graph TB
    subgraph "Manager Node (10.0.1.4)"
        M_Swarm[🐝 Swarm Manager]
        M_DB[🐘 PostgreSQL]
        M_Mon[📊 Prometheus, Grafana, Loki]
    end

    subgraph "Worker 1 (10.0.1.5)"
        W1_API[🐍 API Replica 1]
        W1_Nginx[🐺 Nginx Replica 1]
        W1_Redis[🔴 Redis]
    end

    subgraph "Worker 2 (10.0.1.6)"
        W2_API[🐍 API Replica 2]
        W2_Nginx[🐺 Nginx Replica 2]
    end
```

> **Note:** This is the default placement. Swarm may redistribute based on resource availability and constraints.

---

## 3. Sequence Diagrams

### 3.1 User Request Flow

```mermaid
sequenceDiagram
    actor User
    participant DNS
    participant Nginx
    participant API
    participant DB
    participant Redis
    participant Prometheus

    User->>DNS: Resolve swarmfort.example.com
    DNS-->>User: Manager Node IP
    User->>Nginx: HTTPS GET /api/data
    Nginx->>Nginx: TLS Termination
    Nginx->>API: HTTP Proxy (backend-net)
    API->>Redis: Check Cache (database-net)
    alt Cache Hit
        Redis-->>API: Return Cached Data
    else Cache Miss
        API->>DB: SQL Query (database-net)
        DB-->>API: Return Result
        API->>Redis: Update Cache
    end
    API-->>Nginx: JSON Response
    Nginx-->>User: HTTPS Response
    API->>Prometheus: Record Metrics (/metrics)
```

### 3.2 CI/CD Deployment Flow

```mermaid
sequenceDiagram
    actor Dev as Developer
    participant Git as GitHub
    participant CI as GitHub Actions
    participant Registry as Docker Registry
    participant Swarm as Swarm Manager
    participant Node as Swarm Worker

    Dev->>Git: git push (PR)
    Git->>CI: Trigger ci.yml
    CI->>CI: Build (multi-arch)
    CI->>CI: Hadolint
    CI->>CI: Trivy Scan
    CI->>CI: OPA/Conftest
    CI->>CI: Structure Tests
    CI->>CI: Generate SBOM

    Dev->>Git: Merge PR
    Git->>CI: Trigger release.yml (manual)
    CI->>CI: Build & Push Image
    CI->>Registry: Push signed image (Cosign + DCT)
    CI->>Registry: Attach SLSA Provenance
    CI->>Swarm: SSH → docker stack deploy
    Swarm->>Node: Schedule API tasks (rolling update)
    Swarm->>Node: Health check
    Node-->>Swarm: Running (healthy)
    Swarm-->>CI: Deployment Successful
```

---

## 4. Component Breakdown

### 4.1 Ingress & Load Balancing
**Component:** Nginx
- Terminates TLS using certificates stored as Docker secrets (`site.crt`, `site.key`).
- Routes HTTP → HTTPS (301 redirect).
- Proxies API requests to the `api` service via Swarm’s internal DNS.
- Health-checked by Swarm: `wget --spider http://localhost/health` every 30s.

### 4.2 Application Layer
**Component:** API (Python FastAPI)
- Stateless, horizontally scalable (3 replicas).
- Exposes `/health`, `/ping`, `/metrics` (Prometheus), `/db-health`.
- Connected to both `backend-net` (receives traffic) and `database-net` (accesses DB/Redis).
- Rolling updates: parallelism 1, delay 10s, failure-action rollback.

### 4.3 Data Layer
**PostgreSQL**
- Single replica (stateful, placed on manager node initially).
- Password via Docker secret (`db_password`).
- Volume: `pgdata` for persistence.
- Health check: `pg_isready -U user -d mydb`.

**Redis**
- Single replica, used for caching.
- Password via Docker secret (`api_key`).
- Health check: `redis-cli ping`.

### 4.4 Observability Stack
| Service | Role | Port | Data Source |
|---------|------|------|-------------|
| Prometheus | Metrics aggregation | 9090 | cAdvisor, Node Exporter, API `/metrics` |
| Grafana | Dashboards (RED + Resource) | 3000 | Prometheus |
| Loki | Log aggregation | 3100 | Fluentd, Docker event exporter |
| cAdvisor | Container metrics | 8080 | Docker daemon |
| Node Exporter | Host metrics | 9100 | `/proc`, `/sys` |
| Fluentd | Log forwarder | 24224 | Docker log driver → Loki |
| Docker Events Exporter | Swarm event streaming | - | Docker socket → Loki |

### 4.5 Security Components
| Component | Location | Function |
|-----------|----------|----------|
| Seccomp profile | `infra/security/seccomp-profiles/custom-seccomp.json` | Whitelists ~300 syscalls for API containers |
| AppArmor profile | `infra/security/apparmor-profiles/usr.bin.custom-app` | Mandatory access control for Python binary |
| OPA Image Policy | `infra/security/opa-policies/image-policy.rego` | Enforces `com.example.sec-approved=true` label |
| OPA Runtime Policy | `infra/security/opa-policies/runtime-policy.rego` | Enforces capabilities, read-only rootfs, no-new-privileges |
| DCT Delegation | `infra/security/content-trust/delegation-roles.json` | Offline root key, signer/releaser roles |
| SLSA Policy | `infra/security/slsa-provenance-policy.yaml` | Verifies provenance attestations |
| Docker Bench | `infra/security/docker-bench-security.sh` | CIS benchmark audit |
| Auditd Rules | `infra/security/docker-audit.rules` | Monitors Docker binary, socket, configs |

### 4.6 Operational Tooling
| Script | Purpose |
|--------|---------|
| `backup-swarm.sh` | Encrypts `/var/lib/docker/swarm` → `.tar.gz.gpg` |
| `restore-swarm.sh` | Decrypts and restores swarm state + volumes |
| `rotate-secrets.sh` | Rotates DB password and API key with zero downtime |
| `overlay-encryption-rotation.sh` | Creates new encrypted network, migrates services, removes old one |
| `cleanup-disk.sh` | Prunes resources older than 72 hours |
| `cleanup-cron-setup.sh` | Schedules disk cleanup at 2AM via cron |
| `promote-canary.sh` | Shifts traffic to canary, checks Prometheus error rate, promotes or rolls back |
| `diagnostic.sh` | Collects system state during incidents (nodes, services, targets, disk, memory) |

---

## 5. Security Architecture (Defense in Depth)

```mermaid
graph TD
    subgraph Supply Chain
        SC1[DCT Signing]
        SC2[Cosign Signing]
        SC3[Trivy Scan]
        SC4[SBOM Generation]
        SC5[OPA Image Policy]
    end

    subgraph Runtime
        RT1[Non-root User]
        RT2[Seccomp Profile]
        RT3[AppArmor Profile]
        RT4[Capability Drop]
        RT5[no-new-privileges]
        RT6[Read-only Rootfs]
        RT7[User Namespace Remap]
    end

    subgraph Network
        NW1[IPsec Overlay Encryption]
        NW2[Network Isolation - 3 Tiers]
        NW3[TLS Termination - Nginx]
        NW4[Minimal Port Exposure]
    end

    subgraph Data at Rest
        DR1[Encrypted Backups - GPG]
        DR2[Docker Secrets]
        DR3[Auditd Monitoring]
    end

    SC1 --> RT1
    SC2 --> RT1
    SC3 --> RT1
    SC4 --> RT1
    SC5 --> RT1
    RT1 --> NW1
    RT2 --> NW1
    RT3 --> NW1
    RT4 --> NW1
    RT5 --> NW1
    RT6 --> NW1
    RT7 --> NW1
    NW1 --> DR1
    NW2 --> DR1
    NW3 --> DR1
    NW4 --> DR1
```

---

## 6. Failure Mode Analysis

| Failure Scenario | Impact | Mitigation | Recovery Time |
|-----------------|--------|------------|---------------|
| **Manager Node Down** | Swarm control plane unavailable; existing services continue running | Multiple managers (future); `backup-swarm.sh` for fast recovery | ~10 min (restore from backup) |
| **Worker Node Down** | Services reschedule to remaining nodes | Swarm self-healing; `kill-random-node.sh` chaos test validates this | ~30 sec (Swarm reschedule) |
| **PostgreSQL Crash** | API returns 500 for DB-dependent endpoints | Health check (`pg_isready`) triggers restart; volume persistence | ~30 sec (container restart) |
| **Redis Crash** | Cache misses; API still functional but slower | Health check triggers restart; stateless | ~30 sec |
| **Nginx Config Error** | 502 Bad Gateway for all requests | Rolling update failure_action=rollback; previous config restored | ~20 sec (rollback) |
| **Docker Daemon Crash** | All containers on that node stop | `live-restore: true` in daemon.json; containers continue running during daemon restart | ~5 sec (daemon restart) |
| **IPsec Key Compromise** | Overlay traffic potentially decryptable | `overlay-encryption-rotation.sh` creates new network, migrates services | ~5 min (automated rotation) |
| **Registry Unavailable** | Cannot pull new images; existing containers unaffected | Docker Hub/self-hosted registry HA; local image cache on nodes | Varies (depends on registry recovery) |
| **Disk Full** | Services cannot write logs/data; images cannot be pulled | `cleanup-disk.sh` or expand disk in Azure | ~5 min (cleanup) or ~15 min (disk expansion) |
| **OOM Kill** | Container terminated; service may degrade | Increase memory limits, scale replicas; SLO alert triggers | ~1 min (container restart) |

---

## 7. Capacity & Scalability

| Metric | Current Limit | Scaling Strategy |
|--------|--------------|------------------|
| **Nodes** | 3 (1 manager + 2 workers) | Add workers via `join-worker.sh`; promote additional managers for HA |
| **API Replicas** | 3 (configurable) | Increase `replicas` in stack; Swarm load balances automatically |
| **Database Connections** | PostgreSQL default (100) | Connection pooling via PgBouncer; vertical scaling for DB VM |
| **Redis Memory** | 256 MB limit | Vertical scaling; or Redis Cluster for horizontal scaling |
| **Max Containers** | ~100 per node (B2ats_v2) | Upgrade VM SKU; distribute services across more nodes |
| **Network Throughput** | ~1 Gbps (Azure B2ats_v2) | Upgrade VM size; IPsec overhead ~5-8% |
| **Log Retention** | Loki: 7 days (default) | Increase `retention_period` in Loki config; add S3 backend |
| **Backup Retention** | 30 days (local) | S3 lifecycle policy for long-term archival |

---

## 8. Design Decisions & Trade-offs

| Decision | Alternative | Rationale |
|----------|-------------|-----------|
| Docker Swarm | Kubernetes | Built-in, zero external dependencies, simpler operations; ideal for teams < 50 engineers |
| Alpine base image | Distroless | Smaller (< 25MB) while still providing a package manager for debugging |
| Nginx | Traefik | More mature, easier to customize for TLS termination and upstream routing |
| Prometheus stack | Datadog, New Relic | No vendor lock-in, no licensing cost, works natively with Swarm service discovery |
| Loki + Fluentd | ELK Stack | Lighter weight, integrates natively with Grafana, same stack as metrics |
| Ansible (primary GitOps) | Flux CD | Ansible can directly manage Docker Swarm; Flux is optional for Kubernetes-style GitOps |
| GPG symmetric encryption (backups) | Cloud KMS | Simpler, portable across clouds; easy to integrate with any S3-compatible storage |
| Self-signed certificates (dev) | Let's Encrypt | Suitable for development; production should use cert-manager or Let's Encrypt with DNS challenge |

---

## 9. Architecture Decision Records (ADR)

| ID | Title | Decision | Rationale |
|----|-------|----------|-----------|
| ADR-001 | Swarm over Kubernetes | Use Docker Swarm | Simpler, built-in, no etcd; sufficient for teams < 50 |
| ADR-002 | Alpine over Distroless | Use Alpine as base | Smaller than distroless, package manager for debugging |
| ADR-003 | Nginx over Traefik | Use Nginx | More mature, easier custom config |
| ADR-004 | Prometheus over Datadog | Use Prometheus stack | Open source, no vendor lock-in, Swarm-native |
| ADR-005 | GPG over Cloud KMS | Use GPG symmetric | Portable across clouds, simpler key management |
| ADR-006 | IPsec over mTLS | Use IPsec overlay encryption | Built into Swarm, no sidecar needed, transparent to apps |

> Full ADR documents available in `docs/adr/` directory.

---

## 10. Cost Estimation (Azure - Malaysia West)

| Resource | SKU | Monthly Cost (USD) |
|----------|-----|-------------------|
| 3 × VMs (B2ats_v2) | 2 vCPU, 4 GB RAM | ~$90 |
| 3 × Managed Disks (30 GB) | Standard SSD | ~$15 |
| Public IP | Static | ~$5 |
| Bandwidth (outbound) | ~100 GB estimated | ~$10 |
| **Total (estimated)** | | **~$120/month** |

> Costs are approximate and vary by region, usage, and reserved instance discounts.

---

## 11. Technology Stack

| Category | Technology | Version |
|----------|-----------|---------|
| Orchestrator | Docker Swarm | 24+ |
| Ingress | Nginx | Alpine |
| Application | Python FastAPI | 3.12 |
| Database | PostgreSQL | 15 |
| Cache | Redis | 7 |
| Metrics | Prometheus | Latest |
| Dashboards | Grafana | Latest |
| Logs | Loki | Latest |
| Log Shipper | Fluentd | v1.16 |
| Container Metrics | cAdvisor | Latest |
| Host Metrics | Node Exporter | Latest |
| IaC | Terraform | 1.5+ |
| CI/CD | GitHub Actions | - |
| Signing | Cosign, DCT | - |
| Provenance | SLSA | L2+ |
| Security Scan | Trivy | Latest |
| Policy Engine | OPA/Conftest | Latest |
| GitOps | Ansible (primary), Flux (optional) | - |

---

## 12. Future Considerations

- **Auto-scaling**: Docker Swarm autoscaler with Prometheus metrics triggers.
- **Let's Encrypt**: Replace self-signed certificates with cert-manager or ACME client.
- **PostgreSQL HA**: Patroni or pgpool for automatic failover.
- **Multi-cloud**: Terraform modules for AWS, GCP, on-premise.
- **Service Mesh**: Istio or Consul Connect for mTLS (currently IPsec suffices).
- **Distributed Tracing**: OpenTelemetry + Jaeger/Tempo.

---

**SwarmFort Architecture** — Designed for simplicity, hardened for production, documented for engineers.