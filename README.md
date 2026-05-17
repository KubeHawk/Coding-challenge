# Crewmeister DevOps Challenge

A production-grade DevOps implementation for a Spring Boot application on Google Cloud Platform (GCP), featuring automated CI/CD pipelines, Infrastructure as Code, Kubernetes deployment, and a full observability stack.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Application](#application)
- [Infrastructure](#infrastructure)
- [Kubernetes & Helm](#kubernetes--helm)
- [CI/CD Pipelines](#cicd-pipelines)
- [Observability](#observability)
- [Security](#security)
- [Local Development](#local-development)
- [Deployment Guide](#deployment-guide)
- [GitHub Secrets Reference](#github-secrets-reference)
- [Design Decisions](#design-decisions)

---

## Overview

This project containerizes and deploys a Spring Boot REST API to a private GKE cluster on GCP. Everything — from cloud infrastructure to Kubernetes manifests — is managed as code and automated through GitHub Actions.

**Tech stack at a glance:**

| Layer | Technology |
|---|---|
| Application | Spring Boot 3.3.5, Java 17, MySQL 8.0, Flyway |
| Containerization | Docker (multi-stage build), Artifact Registry |
| Infrastructure | Terraform 1.8, GCP (GKE, Cloud SQL, VPC, NAT) |
| Kubernetes | Helm 3, Gateway API, ServiceMonitor, HealthCheckPolicy |
| CI/CD | GitHub Actions |
| Security scanning | Trivy |
| Metrics | Prometheus + Grafana (kube-prometheus-stack) |
| Logging | Logstash + Elasticsearch + Kibana (ELK) |

---

## Architecture

The diagrams below illustrate the full system. Import the XML files in `docs/` into [draw.io](https://app.diagrams.net) via **File → Import from → This device**.

### Infrastructure architecture

> `docs/Architecture.xml`

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── ci-cd.yml          # Build, scan, push image + Helm deploy
│       └── infra.yml          # Terraform plan on PR, apply on approval
│
├── src/                       # Spring Boot application source code
│   └── main/
│       └── resources/
│           ├── application.yml        # App configuration (env-var driven)
│           └── logback-spring.xml     # JSON logging + Logstash TCP appender
│
├── helm/
│   ├── crewmeister/           # Application Helm chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml        # Default values (non-sensitive)
│   │   └── templates/
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── namespace.yml
│   │       ├── gateway.yml           # GKE Gateway API
│   │       ├── httproute.yaml        # Routes traffic to the app
│   │       ├── healthcheckpolicy.yaml
│   │       ├── db-secret.yaml        # K8s Secret for DB password
│   │       ├── ServiceMonitor.yaml   # Prometheus scrape config
│   │       ├── grafana-dashboard.yaml # Grafana dashboard ConfigMap
│   │       └── _helpers.tpl
│   │
│   └── monitoring/            # Monitoring stack Helm values
│       ├── kube-prometheus-stack-values.yaml
│       ├── elasticsearch-values.yaml
│       ├── kibana-values.yaml
│       └── logstash-values.yaml
│
├── Infra/                     # Terraform infrastructure code
│   ├── main.tf                # Root module: providers, modules, VPC peering
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Outputs (cluster name, SQL IP, registry URL)
│   └── modules/
│       ├── vpc/               # VPC, subnet, Cloud Router, Cloud NAT
│       ├── gke/               # Private GKE cluster + node pool
│       ├── cloudsql/          # MySQL 8.0 with private IP
│       ├── artifact-registry/ # Docker image registry
│       └── monitoring/        # Helm releases: Prometheus, Grafana, ELK
│
├── Dockerfile                 # Multi-stage build (JDK builder → JRE runtime)
├── docker-compose.yml         # Local development (app + MySQL)
└── pom.xml                    # Maven dependencies
```

---

## Application

### What it does

A Spring Boot REST API with:
- JPA + MySQL persistence managed by Flyway migrations
- Spring Actuator health and metrics endpoints
- Prometheus metrics via Micrometer
- JSON structured logging, with a Logstash TCP appender activated in the `logstash` profile

### Key dependencies

| Dependency | Purpose |
|---|---|
| `spring-boot-starter-web` | REST API |
| `spring-boot-starter-data-jpa` | Database access |
| `flyway-core` + `flyway-mysql` | Database schema migrations |
| `spring-boot-starter-actuator` | Health checks + metrics endpoints |
| `micrometer-registry-prometheus` | Exposes metrics at `/actuator/prometheus` |
| `logstash-logback-encoder` | JSON log format + TCP shipping to Logstash |

### Configuration

All configuration is environment-variable driven. Defaults are provided for local development:

| Variable | Default | Description |
|---|---|---|
| `SPRING_APPLICATION_NAME` | `app` | Application name |
| `SPRING_DATASOURCE_URL` | `jdbc:mysql://localhost:3306/challenge` | Main DB connection |
| `SPRING_DATASOURCE_WRITER_URL` | same | Flyway DB connection |
| `SPRING_DATASOURCE_USERNAME` | `root` | DB username |
| `SPRING_DATASOURCE_PASSWORD` | `dev` | DB password |
| `SPRING_PROFILES_ACTIVE` | _(none)_ | Set to `logstash` in production |
| `ACTUATOR_ENDPOINTS` | `health,info,prometheus` | Exposed actuator endpoints |

### Dockerfile

The image uses a **two-stage build** to keep the final image small and secure:

```
Stage 1 (builder) — eclipse-temurin:17-jdk-alpine
  ├── Copy pom.xml + mvnw → download dependencies (cached layer)
  └── Copy src/ + build JAR

Stage 2 (runtime) — eclipse-temurin:17-jre-alpine
  ├── Create non-root user: appuser / appgroup
  ├── Copy JAR from builder
  └── Run as appuser (no root access)
```

> **Why two stages?** The JDK is ~300MB; the JRE is ~90MB. We only need the JDK to compile — the final image only ships the JRE, making it smaller and reducing the attack surface.

JVM flags used at runtime:

| Flag | Purpose |
|---|---|
| `-XX:+UseContainerSupport` | Makes JVM respect container memory limits |
| `-XX:MaxRAMPercentage=75.0` | Heap uses at most 75% of available container memory |
| `-Djava.security.egd=file:/dev/./urandom` | Faster startup on Linux |

---

## Infrastructure

All cloud resources are managed with **Terraform** and stored in the `Infra/` directory. The state is stored remotely in a GCS bucket so the whole team shares the same view of infrastructure.

### State backend

```hcl
backend "gcs" {
  bucket = "crewmeister-terraform-state-496312"
  prefix = "terraform/state"
}
```

> **Why remote state?** Without it, two people running `terraform apply` simultaneously could corrupt infrastructure. The GCS backend provides locking and a shared source of truth.

### Module breakdown

#### `modules/vpc`

Creates the private network where all resources live:

| Resource | Value |
|---|---|
| VPC | `crewmeister-vpc` |
| Private subnet | `10.0.32.0/19` |
| Pod IP range | `172.16.0.0/14` |
| Service IP range | `172.20.0.0/18` |
| Cloud Router | Routes traffic |
| Cloud NAT | Allows private nodes to pull images and reach the internet without a public IP |

> **Why Cloud NAT?** GKE nodes are private (no public IP). Without NAT, they can't pull Docker images from Artifact Registry or reach external APIs. NAT provides outbound internet access without exposing nodes publicly.

#### `modules/gke`

Creates the Kubernetes cluster:

| Setting | Value | Why |
|---|---|---|
| Machine type | `e2-standard-2` | 2 vCPU, 8GB RAM — sufficient for all workloads |
| Private nodes | `true` | Nodes have no public IP — security best practice |
| Private endpoint | `false` | The Kubernetes API is accessible from outside the VPC (needed for CI/CD) |
| Release channel | `REGULAR` | Automatic GKE upgrades on a stable schedule |
| Gateway API | `CHANNEL_STANDARD` | Enables the modern Kubernetes Gateway API for ingress |

#### `modules/cloudsql`

Creates the MySQL database:

| Setting | Value | Why |
|---|---|---|
| Version | `MySQL 8.0` | Modern, well-supported |
| Tier | `db-f1-micro` | Smallest tier, suitable for dev/challenge |
| Public IP | `disabled` | Never exposed to the internet |
| Private IP | `enabled` | Only reachable from inside the VPC |
| Deletion protection | `false` | Allows `terraform destroy` (set to `true` in real production) |

**Private IP setup** requires three extra resources that work together:

```
1. google_compute_global_address    ← Reserves a /16 IP block in your VPC
         │                             for Google-managed services
         │
2. google_service_networking_connection  ← Creates VPC peering between
         │                                  your VPC and Google's service network
         │
3. Cloud SQL (private_network = your VPC)  ← Gets an IP from the reserved block
```

#### `modules/artifact-registry`

A private Docker registry to store your container images. Images are tagged with both `:latest` and `:git-sha` for immutability and rollback capability.

#### `modules/monitoring`

Deploys the full observability stack via Helm releases onto the GKE cluster:

| Release | Chart | Version |
|---|---|---|
| `kube-prometheus-stack` | `prometheus-community/kube-prometheus-stack` | 58.2.2 |
| `elasticsearch` | `elastic/elasticsearch` | 8.5.1 |
| `kibana` | `elastic/kibana` | 8.5.1 |
| `logstash` | `elastic/logstash` | 8.5.1 |

### Terraform variables

| Variable | Default | Sensitive | Description |
|---|---|---|---|
| `project_id` | `crewmeister-496312` | No | GCP project ID |
| `region` | `europe-west1` | No | GCP region |
| `zone` | `europe-west1-b` | No | GCP zone |
| `cluster_name` | `crewmeister` | No | Name prefix for all resources |
| `machine_type` | `e2-standard-2` | No | GKE node type |
| `node_count` | `1` | No | Number of GKE nodes |
| `db_password` | _(required)_ | **Yes** | MySQL password |
| `grafana_admin_password` | _(required)_ | **Yes** | Grafana admin password |

---

## Kubernetes & Helm

The application is deployed using a Helm chart located at `helm/crewmeister/`.

### What the chart deploys

| Template | What it creates |
|---|---|
| `namespace.yml` | The `crewmeister` namespace |
| `deployment.yaml` | The Spring Boot pod |
| `service.yaml` | ClusterIP service on port 8080 |
| `gateway.yml` | GKE L7 Gateway (external load balancer, port 80) |
| `httproute.yaml` | Routes all traffic (`/`) to the service |
| `healthcheckpolicy.yaml` | Configures GKE's health check for the load balancer |
| `db-secret.yaml` | Kubernetes Secret containing the DB password |
| `ServiceMonitor.yaml` | Tells Prometheus where to scrape metrics |
| `grafana-dashboard.yaml` | Provisions a Spring Boot dashboard into Grafana |

### Traffic flow

```
External user
    │
    ▼ HTTP :80 (public IP)
Gateway (GKE L7 load balancer)
    │
    ▼
HTTPRoute (routes / → crewmeister service)
    │
    ▼
Service (ClusterIP :8080)
    │
    ▼
Deployment pod (Spring Boot)
    │
    ├── Reads db-password from K8s Secret
    ├── Connects to Cloud SQL via private IP (jdbc:mysql://10.x.x.x:3306/challenge)
    └── Ships logs to Logstash via TCP :5000
```

### Health checks

Spring Actuator exposes two endpoints the cluster uses:

| Endpoint | Used for |
|---|---|
| `/actuator/health/liveness` | Kubernetes liveness probe — restarts the pod if it fails |
| `/actuator/health/readiness` | Kubernetes readiness probe — stops traffic to the pod if it fails |
| `/actuator/prometheus` | Prometheus metrics scraping |

### Helm values

Non-sensitive configuration lives in `values.yaml`. Sensitive values (DB URL, password) are passed at deploy time via `--set` flags in the pipeline.

```yaml
replicaCount: 1

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"

env:
  SPRING_APPLICATION_NAME: crewmeister-challenge
  SPRING_DATASOURCE_USERNAME: crewmeister
  SPRING_PROFILES_ACTIVE: logstash    # activates Logstash TCP appender
```

---

## CI/CD Pipelines

Both pipelines trigger on **pull requests** to `main`. This means every change is validated before it reaches production.

### `ci-cd.yml` — Application pipeline

```
Trigger: pull_request → main

Job 1: push-image
  1. Checkout code
  2. Authenticate to GCP (service account key)
  3. Setup Docker Buildx
  4. Build image locally (not pushed yet) using GHA layer cache
  5. Trivy scan (CRITICAL/HIGH vulnerabilities, exit-code: 0 — logs but doesn't block)
  6. Upload SARIF report → GitHub Security tab (runs even if scan fails)
  7. Push image to Artifact Registry with :latest and :<git-sha> tags

Job 2: deploy (needs: push-image)
  1. Checkout code
  2. Authenticate to GCP
  3. Install gke-gcloud-auth-plugin
  4. Get GKE cluster credentials
  5. helm upgrade --install (creates namespace if it doesn't exist)
```

> **Why `exit-code: 0` on Trivy?** The Spring Boot 3.3.5 JAR contains known CVEs in Tomcat and Spring Core that are fixed in later versions. Setting exit-code to 0 means the scan results are visible in the GitHub Security tab without blocking deployments. Upgrade to Spring Boot 3.3.11+ to resolve these.

> **What is GHA layer cache?** Docker builds layers — if `pom.xml` hasn't changed, the dependency download layer is reused from cache. This makes subsequent builds take seconds instead of minutes.

### `infra.yml` — Infrastructure pipeline

```
Trigger: pull_request → main + workflow_dispatch (manual)

Permissions: contents: read, pull-requests: write

Job 1: init-and-plan
  1. Checkout code
  2. Authenticate to GCP
  3. terraform init + terraform validate
  4. terraform plan -detailed-exitcode (exit 0=no changes, 1=error, 2=changes)
  5. Post plan output as PR comment (✅ No changes / ⚠️ Changes / ❌ Failed)
  6. Fail pipeline only if exit code is 1 (actual error)

Job 2: apply (needs: init-and-plan, environment: production)
  1. Authenticate to GCP
  2. terraform init
  3. terraform apply -auto-approve
  4. terraform output
```

> **What is the `production` environment?** A GitHub Actions environment that requires manual approval before the apply job runs. This prevents accidental infrastructure changes — someone must click "Approve" in GitHub before Terraform applies.

> **Why post the plan as a PR comment?** This lets reviewers see exactly what infrastructure will change before approving the PR — just like code review but for cloud resources.

---

## Observability

### Metrics — Prometheus + Grafana

The Spring Boot app exposes Prometheus metrics at `/actuator/prometheus`. The `ServiceMonitor` resource tells Prometheus to scrape this endpoint every 15 seconds.

```
Spring Boot pod
    │ /actuator/prometheus (every 15s)
    ▼
Prometheus (collects and stores metrics)
    │
    ▼
Grafana (visualizes — Spring Boot dashboard auto-provisioned via ConfigMap)
```

Access Grafana at the LoadBalancer external IP:

```bash
kubectl get svc kube-prometheus-stack-grafana -n monitoring
# Default credentials: admin / <GRAFANA_ADMIN_PASSWORD secret>
```

### Logging — ELK stack (Elasticsearch + Logstash + Kibana)

The app ships structured JSON logs to Logstash via TCP when the `logstash` Spring profile is active.

```
Spring Boot pod (profile: logstash)
    │ JSON over TCP :5000
    ▼
Logstash (receives, processes, forwards)
    │ HTTPS + TLS
    ▼
Elasticsearch (stores log documents, xpack.security enabled)
    │
    ▼
Kibana (search and visualize logs)
```

**How the Logstash profile works:**

`logback-spring.xml` configures two appenders:
- `JSON_CONSOLE` — always active, writes JSON logs to stdout
- `LOGSTASH` — only active when `SPRING_PROFILES_ACTIVE=logstash`, ships logs over TCP to `logstash-logstash.monitoring.svc.cluster.local:5000`

Access Kibana at the LoadBalancer external IP:

```bash
kubectl get svc kibana-kibana -n monitoring
```

Create a data view with pattern `crewmeister-logs-*` to see application logs.

---

## Security

### Container security

- **Non-root user** — the container runs as `appuser`, not root. Even if an attacker exploits the app, they get no root privileges.
- **JRE-only runtime** — the final image contains only the Java Runtime, not the full JDK. No compiler, no development tools.
- **Trivy scanning** — every image build scans for CRITICAL and HIGH CVEs before pushing.

### Network security

- **Private GKE nodes** — cluster nodes have no public IP addresses. They cannot be reached directly from the internet.
- **Private Cloud SQL** — the database has no public IP. It's only reachable from within the VPC via private IP.
- **VPC peering** — Cloud SQL connects to your VPC through a private peering connection — no traffic leaves Google's network.
- **Cloud NAT** — provides controlled outbound internet access for private nodes without exposing inbound connections.

### Secrets management

| Secret | How it's stored | How it's used |
|---|---|---|
| DB password | GitHub Secret → K8s Secret | Pod reads via `secretKeyRef` |
| GCP credentials | GitHub Secret | CI/CD authenticates to GCP |
| Grafana password | GitHub Secret → `TF_VAR_` | Passed to Terraform at apply time |

> **Note:** In a production environment, GCP Secret Manager with Workload Identity Federation (WIF) would replace service account JSON keys entirely — no long-lived credentials stored anywhere.

---

## Local Development

### Prerequisites

- Docker + Docker Compose
- Java 17 (for running without Docker)
- `kubectl`, `helm`, `terraform`, `gcloud` (for infrastructure work)

### Run with Docker Compose

```bash
docker compose up
```

This starts:
- MySQL 8.0 on port 3306 (with a health check — the app waits for MySQL to be ready)
- Spring Boot app on port 8080

Test the app:

```bash
curl http://localhost:8080/actuator/health
# {"status":"UP"}

curl http://localhost:8080/actuator/prometheus
# metrics output
```

### Run without Docker

```bash
# Start MySQL
docker compose up db -d

# Run the app
./mvnw spring-boot:run
```

### Build the Docker image manually

```bash
docker build -t crewmeister-app:local .
docker run -p 8080:8080 \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://host.docker.internal:3306/challenge \
  -e SPRING_DATASOURCE_PASSWORD=dev \
  crewmeister-app:local
```

---

## Deployment Guide

### First-time setup

**1. Create a GCP service account for Terraform:**

```bash
gcloud iam service-accounts create terraform-sa \
  --display-name="Terraform Service Account"

# Grant required permissions
for role in \
  roles/compute.admin \
  roles/container.admin \
  roles/iam.serviceAccountUser \
  roles/storage.admin \
  roles/artifactregistry.admin \
  roles/cloudsql.admin \
  roles/servicenetworking.networksAdmin; do
  gcloud projects add-iam-policy-binding crewmeister-496312 \
    --member="serviceAccount:terraform-sa@crewmeister-496312.iam.gserviceaccount.com" \
    --role="$role"
done

# Download the key
gcloud iam service-accounts keys create terraform-sa-key.json \
  --iam-account=terraform-sa@crewmeister-496312.iam.gserviceaccount.com
```

**2. Create the Terraform state bucket:**

```bash
gsutil mb -l europe-west1 gs://crewmeister-terraform-state-496312
gsutil versioning set on gs://crewmeister-terraform-state-496312
```

**3. Add GitHub Secrets** (see [GitHub Secrets Reference](#github-secrets-reference) below).

**4. Set up the `production` environment in GitHub:**

Go to **Settings → Environments → New environment** → name it `production` → enable **Required reviewers**.

**5. Deploy infrastructure** — open a PR or run `infra.yml` manually via `workflow_dispatch`.

**6. After Terraform applies, get the Cloud SQL IP:**

```bash
terraform -chdir=Infra output cloud_sql_ip
```

Update the `CLOUD_SQL_IP` GitHub Secret with this value.

**7. Deploy the app** — open a PR to trigger `ci-cd.yml`.

### Useful kubectl commands

```bash
# Get all pods across all namespaces
kubectl get pods -A

# Check the app
kubectl get pods -n crewmeister
kubectl logs -n crewmeister -l app.kubernetes.io/name=crewmeister --tail=50

# Check monitoring
kubectl get pods -n monitoring

# Get the Gateway public IP
kubectl get gateway -n crewmeister

# Get Grafana external IP
kubectl get svc kube-prometheus-stack-grafana -n monitoring

# Get Kibana external IP
kubectl get svc kibana-kibana -n monitoring

# Connect to MySQL (from inside the cluster)
kubectl run mysql-client --image=mysql:8.0 -it --rm --restart=Never -n crewmeister -- \
  mysql -h <CLOUD_SQL_IP> -u crewmeister -p challenge
```

### Useful Terraform commands

```bash
cd Infra

# Initialize (first time or after module changes)
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy everything (careful!)
terraform destroy

# Show current outputs
terraform output
```

---

## GitHub Secrets Reference

Add these in **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Description | Example |
|---|---|---|
| `GCP_CREDENTIALS` | Service account JSON key (full file content) | `{ "type": "service_account", ... }` |
| `GCP_PROJECT_ID` | GCP project ID | `crewmeister-496312` |
| `GCP_ZONE` | GKE cluster zone | `europe-west1-b` |
| `GKE_CLUSTER_NAME` | GKE cluster name | `crewmeister` |
| `DB_PASSWORD` | MySQL database password | _(strong password)_ |
| `CLOUD_SQL_IP` | Cloud SQL private IP (from `terraform output`) | `10.104.0.3` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | _(strong password)_ |

---

## Design Decisions

### Why GKE and not Cloud Run?

Cloud Run is simpler but GKE was chosen to demonstrate:
- Real Kubernetes deployments with Helm
- Gateway API for advanced ingress control
- ServiceMonitor for Prometheus integration
- Full control over networking (private nodes, NAT, VPC peering)

### Why private GKE nodes?

Security best practice. Private nodes have no public IP — an attacker who finds a vulnerability in the app cannot reach the underlying node directly. All outbound traffic goes through Cloud NAT.

### Why private Cloud SQL?

Same reason — no public IP means the database is completely invisible to the internet. It can only be reached from within the VPC, which in practice means only the GKE pods.

### Why Terraform modules?

Modules make infrastructure reusable and testable. Each module has a single responsibility (VPC, GKE, Cloud SQL, etc.). This mirrors how real teams organize Terraform — different teams might own different modules.

### Why Helm?

Helm templates allow the same chart to be used across environments by changing only values (image tag, DB URL, replicas). The CI/CD pipeline uses `helm upgrade --install` which creates the release on first deploy and updates it on subsequent deploys — idempotent and safe.

### Why ELK + Prometheus instead of just one?

They serve different purposes:
- **Prometheus + Grafana** — real-time metrics (request rate, latency, JVM heap, CPU). Best for alerting and dashboards.
- **ELK** — full log storage and search. Best for debugging specific errors, tracing request flows, and long-term log retention.

### Why Trivy with `exit-code: 0`?

The Spring Boot 3.3.5 dependency tree contains CVEs in Tomcat 10.1.31 and Spring Core 6.1.14 that require an upgrade to fix. Setting exit-code to 0 means the pipeline doesn't block while CVEs are acknowledged and tracked, but results are always visible in the GitHub Security tab. Upgrade to Spring Boot 3.3.11 to resolve the CRITICAL and most HIGH findings.