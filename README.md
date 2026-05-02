# AeroScale

Event-driven autoscaling system on Google Kubernetes Engine (GKE) using KEDA and GCP Pub/Sub. The system dynamically scales worker pods based on queue depth, optimizing performance and cost.

## Architecture

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────────────┐
│  Publisher   │────▶│  Pub/Sub Topic  │────▶│  Pub/Sub Subscription│
│  (stress)    │     │  event-queue    │     │  event-subscription  │
└──────────────┘     └─────────────────┘     └──────────┬───────────┘
                                                         │
                                                         ▼
                                              ┌─────────────────────┐
                                              │  Worker Pods (1-10) │
                                              │  (aeroscale-worker) │
                                              │  ● /healthz         │
                                              │  ● Subscribe Pub/Sub│
                                              └────────┬────────────┘
                                                       │
                                              ┌────────▼────────────┐
                                              │     KEDA Operator    │
                                              │  ScaledObject trigger│
                                              │  threshold: 50 msgs  │
                                              └─────────────────────┘
```

**Autoscaling flow:**
1. Messages arrive at Pub/Sub topic
2. KEDA polls subscription depth every 10s
3. For every 50 pending messages, KEDA scales up 1 pod (min 1, max 10)
4. When queue drains, pods scale down after 60s cooldown

## Prerequisites

| Tool | Version |
|---|---|
| [gcloud CLI](https://cloud.google.com/cli) | Latest |
| [Terraform](https://www.terraform.io/downloads) | >= 1.7.0 |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | >= 1.28 |
| [Helm](https://helm.sh/docs/intro/install/) | >= 3.14 |
| [Go](https://go.dev/dl/) | >= 1.22 |
| [Docker](https://docs.docker.com/get-docker/) | Latest |

**GCP Authentication:**
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project stayrelevantid
```

**GitHub Actions Secret:**
- `GCP_SA_KEY` — JSON key of a Service Account with roles: `roles/artifactregistry.writer`, `roles/container.admin`, `roles/pubsub.subscriber`

## Quick Start

```bash
# 1. Clone
git clone https://github.com/stayrelevantid/aeroscale.git
cd aeroscale

# 2. Provision infrastructure
cd infrastructure/terraform
terraform init
terraform apply -auto-approve

# 3. Get GKE credentials
gcloud container clusters get-credentials aeroscale-gke \
  --zone=asia-southeast1-a --project=stayrelevantid

# 4. Install KEDA
helm install keda kedacore/keda --namespace keda --version 2.13.2

# 5. Build & deploy worker
cd ../..
./scripts/deploy.sh

# 6. (Optional) Run stress test
./scripts/stress-test.sh
```

## Directory Structure

```
aeroscale/
├── .github/workflows/
│   └── deploy.yml                  # CI/CD pipeline: build → push → deploy
├── cmd/
│   ├── publisher/main.go           # Stress test publisher tool
│   └── worker/main.go              # Worker service entry point
├── internal/
│   ├── health/
│   │   ├── handler.go              # HTTP /healthz handler
│   │   └── handler_test.go         # Unit tests for health handler
│   └── pubsub/
│       ├── subscriber.go           # Pub/Sub subscription logic
│       └── subscriber_test.go      # Unit tests for message processing
├── infrastructure/terraform/
│   ├── providers.tf                # GCP, Helm, K8s providers + GCS backend
│   ├── variables.tf                # Input variables (project_id, region, zone)
│   ├── outputs.tf                  # Output values (cluster endpoint, topic, etc.)
│   ├── main.tf                     # Empty entry point
│   ├── terraform.tfvars            # Variable values
│   ├── vpc.tf                      # VPC, Subnet, Firewall, Cloud NAT+Router
│   ├── gke.tf                      # Private GKE cluster + Node Pool
│   ├── pubsub.tf                   # Pub/Sub topic + subscription
│   ├── iam.tf                      # GSA, Workload Identity, Pub/Sub role
│   ├── artifact_registry.tf        # Docker Artifact Registry repository
│   └── keda.tf                     # KEDA Helm release + namespace
├── k8s/
│   ├── namespace.yaml              # Namespace: aeroscale
│   ├── serviceaccount.yaml         # KSA with Workload Identity annotation
│   ├── deployment.yaml             # Worker Deployment with probes + limits
│   ├── trigger-authentication.yaml # KEDA TriggerAuthentication (GCP pod identity)
│   └── scaled-object.yaml          # KEDA ScaledObject (Pub/Sub trigger)
├── scripts/
│   ├── deploy.sh                   # Build Docker → push → deploy to GKE
│   ├── stress-test.sh              # Publish messages + watch pod scaling
│   ├── destroy.sh                  # Terraform destroy with confirmation
│   ├── audit.sh                    # Audit idle resources (disks, IPs, LBs)
│   ├── cleanup.sh                  # Delete Artifact Registry images + GCS bucket
│   └── billing-audit.sh            # Check billing, APIs, usage
├── Dockerfile                      # Multi-stage Go build (non-root)
├── .dockerignore                   # Docker context exclusions
├── .gitignore                      # Git exclusions
├── go.mod / go.sum                 # Go module dependencies
├── issues.md                       # Task tracker per phase
├── prd.md                          # Product Requirements Document
└── RETROSPECTIVE.md                # Post-mortem & lessons learned
```

## Component Details

### Infrastructure (Terraform)

| File | Resources | Description |
|---|---|---|
| `providers.tf` | GCP, Helm, K8s providers | Configures authentication, GCS remote backend, and dynamic GKE cluster data sources for Helm/K8s providers |
| `variables.tf` | `project_id`, `region`, `zone` | Input variables with defaults: `stayrelevantid`, `asia-southeast1`, `asia-southeast1-a` |
| `outputs.tf` | Cluster endpoint, topic, SA email, etc. | Outputs for reference after `terraform apply` |
| `vpc.tf` | VPC, Subnet, Firewall, Router, NAT | Custom VPC (`10.0.0.0/20`) with Private Google Access, secondary ranges for pods/services, Cloud NAT for private node egress |
| `gke.tf` | GKE Cluster, Node Pool | Private zonal cluster with Workload Identity, e2-medium nodes, autoscaling 1-3 |
| `pubsub.tf` | Topic, Subscription | `aeroscale-event-queue` topic with subscription (60s ack deadline, 7d retention, retry policy) |
| `iam.tf` | GSA, IAM role, WI binding | `aeroscale-worker` GSA with `roles/pubsub.subscriber`, Workload Identity binding to KSA `aeroscale/aeroscale-worker-sa` |
| `artifact_registry.tf` | Docker repository | `aeroscale-docker` in `asia-southeast1` |
| `keda.tf` | K8s namespace, Helm release | KEDA operator v2.13.2 installed via Helm to namespace `keda` |

### Application (Go)

**`cmd/worker/main.go`** — Worker service that:
- Connects to Pub/Sub subscription using GCP default credentials
- Listens for messages on `aeroscale-event-subscription`
- Unmarshals JSON, logs processing, and ACKs messages
- Exposes `/healthz` HTTP endpoint on port 8080
- Handles graceful shutdown on SIGINT/SIGTERM

**`cmd/publisher/main.go`** — Stress test tool with flags:
- `--project` (default: `stayrelevantid`) — GCP project ID
- `--topic` (default: `aeroscale-event-queue`) — Pub/Sub topic
- `--count` (default: `500`) — Number of messages
- `--batch` (default: `10`) — Concurrency batch size
- `--delay` (default: `10ms`) — Delay between batches

**`internal/health/handler.go`** — Returns `{"status":"ok"}` on GET `/healthz`

**`internal/pubsub/subscriber.go`** — Creates Pub/Sub client, receives messages, unmarshals JSON, ACKs on success / NACKs on failure

### Docker

Multi-stage `Dockerfile`:
- **Stage 1** (`golang:1.22-alpine`): Downloads dependencies, builds binary with `CGO_ENABLED=0`
- **Stage 2** (`alpine:3.19`): Copies binary, runs as non-root user `appuser` (UID 1000)

### Kubernetes Manifests

| File | Resource | Description |
|---|---|---|
| `namespace.yaml` | `Namespace/aeroscale` | Isolated namespace for all worker resources |
| `serviceaccount.yaml` | `ServiceAccount/aeroscale-worker-sa` | Annotated with `iam.gke.io/gcp-service-account` for Workload Identity |
| `deployment.yaml` | `Deployment/aeroscale-worker` | 1 replica, resource limits (500m CPU, 256Mi RAM), liveness & readiness probes on `/healthz` |
| `trigger-authentication.yaml` | `TriggerAuthentication` | References GCP Workload Identity pod identity for KEDA to access Pub/Sub metrics |
| `scaled-object.yaml` | `ScaledObject` | Triggers on `gcp-pubsub` subscription size, threshold 50, min replicas 1, max 10, cooldown 60s, polling 10s |

### CI/CD Pipeline (GitHub Actions)

**`.github/workflows/deploy.yml`** triggers on push to `main` when paths change (`cmd/**`, `internal/**`, `Dockerfile`, `go.*`, `k8s/**`):

1. Checkout code
2. Authenticate to GCP via `GCP_SA_KEY` secret
3. Build Docker image tagged with commit SHA + `latest`
4. Push to Artifact Registry
5. Get GKE credentials
6. Apply K8s manifests + update deployment image
7. Wait for rollout (120s timeout)

### Scripts

| Script | Purpose |
|---|---|
| `deploy.sh` | Builds Docker image, pushes to Artifact Registry, deploys to GKE, waits for rollout |
| `stress-test.sh` | Publishes messages via Go publisher, then watches pod scaling in real-time |
| `destroy.sh` | Runs `terraform plan -destroy`, asks confirmation, then `terraform destroy` |
| `audit.sh` | Lists unattached disks, forwarding rules, static IPs, firewalls, Pub/Sub topics, GKE clusters, Artifact Registry repos, Service Accounts |
| `cleanup.sh` | Deletes Artifact Registry images/repository and optionally the GCS state bucket |
| `billing-audit.sh` | Lists billing accounts, enabled APIs, compute usage, provides Console link |

## Configuration

### Worker Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PROJECT_ID` | `stayrelevantid` | GCP Project ID |
| `PUBSUB_SUBSCRIPTION_ID` | `aeroscale-event-subscription` | Pub/Sub subscription name |

### Terraform Variables

| Variable | Default | Description |
|---|---|---|
| `project_id` | `stayrelevantid` | GCP Project ID |
| `region` | `asia-southeast1` | GCP Region |
| `zone` | `asia-southeast1-a` | GCP Zone |

### KEDA Autoscaling Parameters

| Parameter | Value | Description |
|---|---|---|
| `minReplicaCount` | 1 | Always-on pod prevents cold start |
| `maxReplicaCount` | 10 | Cost safety limit |
| `pollingInterval` | 10s | How often KEDA checks Pub/Sub metrics |
| `cooldownPeriod` | 60s | Wait time before scaling down |
| `threshold` | 50 | 1 pod per 50 pending messages |
| `mode` | SubscriptionSize | Scale based on unacked message count |

## Resuming After Targeted Destroy

After running a targeted destroy (GKE cluster + Cloud NAT only), resume with:

```bash
# 1. Re-create infrastructure
cd infrastructure/terraform
terraform apply -auto-approve

# 2. Re-install KEDA via Helm
helm install keda kedacore/keda --namespace keda --version 2.13.2

# 3. Get new GKE credentials
gcloud container clusters get-credentials aeroscale-gke \
  --zone=asia-southeast1-a --project=stayrelevantid

# 4. Re-deploy worker
cd ../..
./scripts/deploy.sh
```

## Testing

```bash
# Unit tests
go test ./...

# Stress test (500 messages, default)
./scripts/stress-test.sh

# Custom stress test
go run ./cmd/publisher --count=1000 --batch=20 --delay=50ms

# Watch scaling
kubectl get pods -n aeroscale -w
kubectl get hpa -n aeroscale -w
```

## Cost Optimization Notes

- GKE cluster uses `e2-medium` (2 vCPU, 4GB RAM) preemptible-ready machines
- Private cluster with Cloud NAT — no external IPs on nodes
- KEDA scales to 0-ish (min 1) during idle, reducing compute cost
- Use `scripts/destroy.sh` for targeted destroy of expensive resources (GKE, NAT) when not in use
- Pub/Sub, VPC, and Service Accounts remain free/low-cost and can stay provisioned

## Project Phases

| Phase | Description | Status |
|---|---|---|
| 1 | Setup Lokal & Remote Backend | ✅ |
| 2 | Infrastructure Build (Terraform Apply) | ✅ |
| 3 | CI/CD Pipeline Aplikasi | ✅ |
| 4 | KEDA Integration | ✅ |
| 5 | Validasi Komprehensif (Stress Test) | ⬜ |
| 6 | Clean-Up & Audit | ⬜ |

See [issues.md](./issues.md) for detailed task tracker and [prd.md](./prd.md) for product requirements.