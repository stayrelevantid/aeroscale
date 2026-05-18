# AeroScale — Retrospective

## Setup yang Digunakan

| Komponen | Detail |
|---|---|
| GCP Project | `stayrelevantid` |
| Region / Zone | `asia-southeast1` / `asia-southeast1-a` |
| GKE Cluster | `aeroscale-gke` (Private Nodes, Workload Identity) |
| Node Pool | `e2-medium`, autoscaling 1-3 |
| VPC | `aeroscale-vpc` (10.0.0.0/20), Private Google Access |
| Cloud NAT | `aeroscale-nat` (untuk node privat) |
| Pub/Sub | Topic `aeroscale-event-queue`, Subscription `aeroscale-event-subscription` |
| Artifact Registry | `aeroscale-docker` (asia-southeast1) |
| KEDA | v2.17.0 (upgraded from v2.13.2), namespace `keda` |
| Worker | Go binary, subscribe Pub/Sub, health check `/healthz`, PROCESS_DELAY support |
| CI/CD | GitHub Actions (deploy.yml) |

---

## Apa yang Berjalan Lancar

- Terraform state tersinkronisasi di GCS backend dengan versioning & lifecycle.
- VPC dengan Private Google Access + Cloud NAT bekerja dengan baik untuk GKE private nodes.
- Workload Identity binding antara KSA dan GSA dikonfigurasi dengan benar.
- Artifact Registry repository dibuat dan diimpor ke Terraform state.
- Worker Go binary dengan health check (`/healthz`) + unit tests passing.
- KEDA ScaledObject dan TriggerAuthentication terdeploy dengan benar.
- **Stress test 500+ messages berhasil** — 0 failures di semua test run.
- **KEDA autoscaling confirmed** — pods scale from 1→10 under load, back to 1 when queue drains.
- **Docker build** untuk `linux/amd64` berhasil dari ARM Mac dengan `--platform` flag.

---

## Tantangan yang Dihadapi

1. **Organization Policy — vmExternalIpAccess**: GKE default node pool mencoba mendapat external IP yang dilarang oleh org policy. Solusi: konfigurasi `private_cluster_config` dengan `enable_private_nodes = true`.
2. **Deletion Protection**: GKE cluster awalnya dibuat dengan `deletion_protection = true`, menyebabkan `terraform destroy` gagal. Solusi: set `deletion_protection = false` dan hapus via `gcloud`.
3. **KEDA Helm Chart Compatibility**: Chart KEDA versi 2.14+ gagal parse YAML di cluster GKE 1.35. Solusi: downgrade ke KEDA chart v2.13.2.
4. **Private Nodes — Image Pull dari ghcr.io**: Node privat tidak bisa pull image dari registry publik (ghcr.io). Solusi: tambahkan Cloud NAT (`google_compute_router_nat`).
5. **GCP Project ID**: Project `aeroscale-438909` tidak ada di akun, diganti ke `stayrelevantid`.
6. **KEDA v2.13.1 tidak compatible dengan K8s 1.35**: ScaledObject tidak menghasilkan HPA. Solusi: upgrade ke KEDA v2.17.0 via Helm.
7. **KEDA operator tidak bisa baca Pub/Sub metrics**: SA KEDA operator tidak punya Workload Identity annotation dan `roles/monitoring.viewer`. Solusi: tambahkan `iam.gke.io/gcp-service-account` annotation ke KEDA operator SA + grant `roles/monitoring.viewer` ke GSA.
8. **Docker image architecture**: Build di ARM Mac menghasilkan image `linux/arm64`. Solusi: build dengan `--platform linux/amd64` dan `GOARCH=amd64` di Dockerfile.
9. **Zone stockout asia-southeast1-a**: e2-medium tidak tersedia di zone a. Solusi: gunakan `node_locations = ["asia-southeast1-b", "asia-southeast1-c"]`.
10. **Worker terlalu cepat memproses pesan**: Tanpa delay, antrian habis sebelum KEDA sempat scale up. Solusi: `PROCESS_DELAY=3s`, `MaxOutstandingMessages=1`, `NumGoroutines=1` untuk simulasi slow consumer.

---

## Lessons Learned

- Selalu validasi project ID dan quota sebelum provisioning.
- Untuk cluster GKE production, selalu gunakan private cluster + Cloud NAT.
- Helm chart versioning harus diverifikasi kompatibel dengan Kubernetes API version yang digunakan.
- Organization policy restrictions harus diantisipasi sejak awal planning.
- Import resource yang dibuat manual (Artifact Registry, Helm release) ke Terraform state untuk konsistensi.

---

## Rekomendasi Improvement

1. **Terraform Modules** — Pecah konfigurasi menjadi reusable modules (network, gke, pubsub).
2. **Remote State Locking** — Tambahkan state locking mechanism (GCS sudah support, tapi pastikan `force_lock` digunakan saat kolaborasi).
3. **Monitoring & Alerting** — Setup Cloud Monitoring dashboard untuk GKE, Pub/Sub metrics, dan KEDA HPA.
4. **Secret Management** — Gunakan Google Secret Manager untuk environment variable yang sensitif daripada hard-code di manifest.
5. **Multi-environment** — Struktur directory `envs/staging` dan `envs/production` dengan `terraform workspace` atau separate state.
6. **Pre-commit Hooks** — Tambahkan `pre-commit` hooks untuk `terraform fmt`, `terraform validate`, dan `go vet`.
7. **CI/CD Secret** — Setup `GCP_SA_KEY` atau Workload Identity Federation di GitHub Actions secrets. **(Done: WIF already configured)**
8. **Cost Optimization** — Pertimbangkan preemptible/spot VM untuk non-production cluster.
9. **Network Policy** — Tambahkan Kubernetes NetworkPolicy untuk restrict pod-to-pod communication.
10. **Pod Disruption Budget** — Tambahkan PDB untuk worker deployment agar zero-downtime during node maintenance.
11. **Production PROCESS_DELAY** — Remove PROCESS_DELAY and MaxOutstandingMessages=1 for production (these are test-only settings to simulate slow consumers).
12. **Monitoring Stack** — Setup Prometheus + Grafana or Cloud Monitoring dashboards for real-time KEDA/HPA metrics visualization.