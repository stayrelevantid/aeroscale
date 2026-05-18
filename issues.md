# Issues & Task Tracker — Project AeroScale

> **Source of Truth** untuk seluruh pengerjaan proyek.
> Referensi: [PRD.md](./PRD.md)

---

## Legend

- ⬜ = Belum dikerjakan
- 🔄 = Sedang dikerjakan
- ✅ = Selesai

---

## Fase 1 — Setup Lokal & Remote Backend

**Objective:** Menyiapkan environment Terraform lokal dan remote state di GCS agar state tersinkronisasi lintas perangkat.

### Tasks

- [x] **1.1 — Buat GCS Bucket untuk Terraform State**
  - Buat bucket GCS secara manual via `gcloud` atau Console.
  - Tentukan nama bucket (misal: `aeroscale-tf-state`).
  - Aktifkan versioning pada bucket untuk safety rollback.
  - Set lifecycle rule (opsional) untuk menghapus versi lama > 30 hari.

- [x] **1.2 — Inisialisasi Project Terraform**
  - Buat struktur direktori Terraform (`infrastructure/terraform/`).
  - Buat file `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, dan `terraform.tfvars`.
  - Konfigurasi `backend "gcs"` di `main.tf` atau `backend.tf` mengarah ke bucket yang sudah dibuat.
  - Jalankan `terraform init` untuk validasi koneksi ke remote backend.

- [x] **1.3 — Konfigurasi Provider GCP**
  - Tentukan `google` provider dengan project ID, region, dan zone yang sesuai.
  - Pastikan credential lokal (`gcloud auth application-default login`) sudah aktif.
  - Tambahkan variable untuk `project_id`, `region`, dan `zone` di `variables.tf`.

- [x] **1.4 — Setup `.gitignore` & Secrets Management**
  - Tambahkan entry `.terraform/`, `*.tfstate`, `*.tfstate.backup`, dan `*.tfvars` ke `.gitignore`.
  - Dokumentasikan cara setup credential di `README.md` atau `CONTRIBUTING.md`.

---

## Fase 2 — Infrastructure Build (Terraform Apply)

**Objective:** Membangun seluruh infrastruktur inti (VPC, GKE Cluster, Pub/Sub) melalui eksekusi Terraform lokal.

### Tasks

- [x] **2.1 — Provisioning VPC & Networking**
  - Definisikan VPC custom di Terraform.
  - Buat subnet untuk GKE nodes.
  - Konfigurasi firewall rules yang diperlukan.
  - Aktifkan Private Google Access pada subnet.

- [x] **2.2 — Provisioning GKE Cluster**
  - Definisikan resource `google_container_cluster` sebagai Standard Zonal Cluster.
  - Aktifkan Workload Identity pada cluster.
  - Konfigurasi Default Node Pool:
    - Machine type: `e2-medium`.
    - Min nodes: `1`.
    - Max nodes: `3`.
    - Autoscaling: enabled.
  - Konfigurasi maintenance window (opsional).
  - Validasi cluster up & running via `gcloud container clusters get-credentials`.

- [x] **2.3 — Provisioning GCP Pub/Sub**
  - Buat resource `google_pubsub_topic` untuk event queue.
  - Buat resource `google_pubsub_subscription` yang terhubung ke topic.
  - Set acknowledgement deadline & message retention sesuai kebutuhan.

- [x] **2.4 — IAM & Service Account Setup**
  - Buat Google Service Account (GSA) untuk worker pod.
  - Berikan role `roles/pubsub.subscriber` pada GSA.
  - Buat IAM binding Workload Identity antara Kubernetes Service Account (KSA) dan GSA.
  - Dokumentasikan mapping KSA ↔ GSA di output Terraform.

- [x] **2.5 — Terraform Plan & Apply**
  - Jalankan `terraform plan` dan review output secara menyeluruh.
  - Jalankan `terraform apply` untuk provisioning semua resource.
  - Simpan output penting (cluster endpoint, Pub/Sub topic name, dsb.) ke `outputs.tf`.
  - Verifikasi semua resource sudah terbuat via GCP Console atau `gcloud`.

---

## Fase 3 — CI/CD Pipeline Aplikasi

**Objective:** Membuat pipeline otomatis untuk build, push, dan deploy aplikasi worker Golang ke GKE.

### Tasks

- [x] **3.1 — Setup Aplikasi Worker Golang**
  - Inisialisasi Go module (`go mod init`).
  - Buat worker sederhana yang subscribe ke Pub/Sub dan memproses pesan.
  - Tambahkan health check endpoint (HTTP `/healthz`).
  - Tulis unit test dasar untuk logika processing.

- [x] **3.2 — Buat Dockerfile**
  - Buat multi-stage Dockerfile untuk build worker Golang.
  - Stage 1: Build binary dengan `golang:1.22-alpine`.
  - Stage 2: Runtime minimal dengan `alpine:3.19` atau `distroless`.
  - Pastikan binary berjalan sebagai non-root user.
  - Test build lokal: `docker build -t aeroscale-worker .`

- [x] **3.3 — Setup Google Artifact Registry**
  - Buat repository di Artifact Registry via Terraform atau manual.
  - Konfigurasi Docker authentication ke Artifact Registry.
  - Test push image secara manual untuk validasi akses.

- [x] **3.4 — Buat Kubernetes Manifests**
  - Buat `Deployment` manifest untuk worker pod.
  - Buat `ServiceAccount` manifest (KSA) dengan annotation Workload Identity.
  - Buat `Namespace` manifest (jika menggunakan namespace terpisah).
  - Validasi manifest dengan `kubectl apply --dry-run=client`.

- [x] **3.5 — Setup CI/CD Pipeline (GitHub Actions)**
  - Buat workflow file `.github/workflows/deploy.yml`.
  - Step 1: Checkout code.
  - Step 2: Authenticate ke GCP via Workload Identity Federation atau Service Account Key.
  - Step 3: Build Docker image & tag dengan commit SHA.
  - Step 4: Push image ke Artifact Registry.
  - Step 5: Update deployment di GKE (`kubectl set image` atau `kubectl apply`).
  - Tambahkan trigger: push ke branch `main`.
  - Test pipeline end-to-end.

---

## Fase 4 — KEDA Integration

**Objective:** Deploy KEDA operator dan konfigurasi ScaledObject agar pod worker auto-scale berdasarkan jumlah pesan Pub/Sub.

### Tasks

- [x] **4.1 — Install KEDA via Helm (Terraform)**
  - Tambahkan Helm provider di Terraform.
  - Definisikan `helm_release` resource untuk KEDA operator.
  - Set namespace: `keda` (buat jika belum ada).
  - Jalankan `terraform apply` untuk install KEDA.
  - Verifikasi KEDA pods running: `kubectl get pods -n keda`.

- [x] **4.2 — Buat TriggerAuthentication Manifest**
  - Buat `TriggerAuthentication` resource yang mereferensikan credential Workload Identity.
  - Pastikan KSA yang digunakan sudah ter-binding ke GSA dengan role Pub/Sub.

- [x] **4.3 — Buat ScaledObject Manifest**
  - Definisikan `ScaledObject` yang menarget Deployment worker.
  - Konfigurasi trigger:
    - Type: `gcp-pubsub`.
    - Subscription name: sesuai resource Pub/Sub yang dibuat.
    - Threshold (value): `50` (1 pod per 50 pending messages).
  - Set kebijakan replika:
    - `minReplicaCount`: `1`.
    - `maxReplicaCount`: `10`.
  - Set `cooldownPeriod` dan `pollingInterval` yang sesuai.

- [x] **4.4 — Deploy & Validasi KEDA**
  - Apply manifest `TriggerAuthentication` dan `ScaledObject` ke cluster.
  - Verifikasi ScaledObject aktif: `kubectl get scaledobject`.
  - Verifikasi HPA terbuat otomatis: `kubectl get hpa`.
  - Cek log KEDA operator untuk memastikan tidak ada error autentikasi.

---

## Fase 5 — Validasi Komprehensif (Stress Test)

**Objective:** Melakukan stress test dengan 500 pesan, menganalisis perilaku HPA/KEDA, dan memastikan monitoring berjalan.

### Tasks

- [x] **5.1 — Buat Script Publisher (Stress Test Tool)**
  - Go publisher (`cmd/publisher/main.go`) with flags: `--count`, `--batch`, `--delay`
  - Tested with 500, 2000, 3000, and 5000 messages — all 0 failures

- [x] **5.2 — Eksekusi Stress Test**
  - 500 msgs: 0 failures, pods scaled 1→4→1
  - 2,000 msgs: 0 failures, pods scaled 1→8→1
  - 5,000 msgs: 0 failures, pods scaled 1→10→1 (peak)

- [x] **5.3 — Analisis HPA & Autoscaling Behavior**
  - Confirmed pods scale up to max (10) under high load
  - Confirmed pods scale down to min (1) after queue drains
  - KEDA polls every 10s, 60s cooldown before scale-down
  - Peak: 2,400/50 average (48x threshold) → 10 pods

- [x] **5.4 — Monitoring & Logging**
  - Worker logs visible via `kubectl logs`
  - Pub/Sub metrics confirmed via `kubectl describe hpa`
  - Scaling timeline fully documented

- [x] **5.5 — Dokumentasi Hasil Validasi**
  - See [VALIDATION_REPORT.md](./VALIDATION_REPORT.md) for full test results, timeline, and conclusions

---

## Fase 6 — Clean-Up & Audit

**Objective:** Terminasi seluruh resource agar tidak ada biaya menggantung, serta audit resource idle.

### Tasks

- [x] **6.1 — Terraform Destroy**
  - `terraform destroy -auto-approve` berhasil menghapus semua resource.
  - GKE cluster (~5 menit), VPC, Subnet, Pub/Sub, SA, IAM bindings, WIF, Cloud NAT/Router, Firewall — semua terhapus.
  - Terraform state kosong (0 resources).

- [x] **6.2 — Audit Resource Idle**
  - `scripts/audit.sh` menunjukkan 5 unattached disks (100GB each) sebelum destroy.
  - Setelah destroy: 0 unattached disks, 0 forwarding rules, 0 static IPs, 0 GKE clusters, 0 Pub/Sub topics.

- [x] **6.3 — Cleanup GCS Backend**
  - GCS bucket `aeroscale-tf-state` (85 objects) dihapus via `gsutil rm -r`.
  - BucketNotFoundException confirmed — bucket fully deleted.

- [x] **6.4 — Cleanup Artifact Registry**
  - Artifact Registry repo `aeroscale-docker` sudah terhapus bareng terraform destroy.

- [x] **6.5 — Final Billing Audit**
  - `scripts/billing-audit.sh` menunjukkan: 0 compute instances, 0 disks, billing aktif tanpa budget alerts.
  - GCP APIs masih aktif (aman, tidak dikenakan biaya kalau tidak dipakai).

- [x] **6.6 — Dokumentasi Post-Mortem**
  - `RETROSPECTIVE.md` dan `issues.md` diperbarui dengan hasil destroy dan lesson learned.

---

## Ringkasan Progress

| Fase | Deskripsi             | Status |
| :--- | :-------------------- | :----- |
| 1    | Setup Lokal & Backend | ✅     |
| 2    | Infrastructure Build  | ✅     |
| 3    | CI/CD Aplikasi        | ✅     |
| 4    | KEDA Integration      | ✅     |
| 5    | Validasi Komprehensif | ✅     |
| 6    | Clean-Up & Audit      | ✅     |
