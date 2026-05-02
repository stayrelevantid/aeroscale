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
| KEDA | v2.13.1, namespace `keda` |
| Worker | Go binary, subscribe Pub/Sub, health check `/healthz` |
| CI/CD | GitHub Actions (deploy.yml) |

---

## Apa yang Berjalan Lancar

- Terraform state tersinkronisasi di GCS backend dengan versioning & lifecycle.
- VPC dengan Private Google Access + Cloud NAT bekerja dengan baik untuk GKE private nodes.
- Workload Identity binding antara KSA dan GSA dikonfigurasi dengan benar.
- Artifact Registry repository dibuat dan diimpor ke Terraform state.
- Worker Go binary dengan health check (`/healthz`) + unit tests passing.
- KEDA ScaledObject dan TriggerAuthentication terdeploy dengan benar.

---

## Tantangan yang Dihadapi

1. **Organization Policy — vmExternalIpAccess**: GKE default node pool mencoba mendapat external IP yang dilarang oleh org policy. Solusi: konfigurasi `private_cluster_config` dengan `enable_private_nodes = true`.
2. **Deletion Protection**: GKE cluster awalnya dibuat dengan `deletion_protection = true`, menyebabkan `terraform destroy` gagal. Solusi: set `deletion_protection = false` dan hapus via `gcloud`.
3. **KEDA Helm Chart Compatibility**: Chart KEDA versi 2.14+ gagal parse YAML di cluster GKE 1.35. Solusi: downgrade ke KEDA chart v2.13.2.
4. **Private Nodes — Image Pull dari ghcr.io**: Node privat tidak bisa pull image dari registry publik (ghcr.io). Solusi: tambahkan Cloud NAT (`google_compute_router_nat`).
5. **GCP Project ID**: Project `aeroscale-438909` tidak ada di akun, diganti ke `stayrelevantid`.

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
7. **CI/CD Secret** — Setup `GCP_SA_KEY` atau Workload Identity Federation di GitHub Actions secrets.
8. **Cost Optimization** — Pertimbangkan preemptible/spot VM untuk non-production cluster.
9. **Network Policy** — Tambahkan Kubernetes NetworkPolicy untuk restrict pod-to-pod communication.
10. **Pod Disruption Budget** — Tambahkan PDB untuk worker deployment agar zero-downtime during node maintenance.