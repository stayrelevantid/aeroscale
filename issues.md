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

- [ ] **5.1 — Buat Script Publisher (Stress Test Tool)**
  - Buat script Go/Python untuk publish 500 pesan ke Pub/Sub topic.
  - Tambahkan opsi konfigurasi: jumlah pesan, batch size, delay antar pesan.
  - Test publish beberapa pesan kecil terlebih dahulu untuk validasi koneksi.

- [ ] **5.2 — Eksekusi Stress Test**
  - Publish 500 pesan ke topic.
  - Pantau proses scaling pod secara real-time:
    ```bash
    kubectl get pods -w
    kubectl get hpa -w
    ```
  - Catat timeline scaling: berapa lama dari publish → scale-up → scale-down.

- [ ] **5.3 — Analisis HPA & Autoscaling Behavior**
  - Verifikasi pod naik mendekati batas (max 10) saat beban tinggi.
  - Verifikasi pod turun ke minimum (1) setelah antrian kosong.
  - Cek `kubectl describe hpa` untuk melihat metric dan keputusan scaling.
  - Dokumentasikan hasil:
    - Jumlah pod peak.
    - Waktu scale-up.
    - Waktu scale-down (cooldown).

- [ ] **5.4 — Monitoring & Logging**
  - Pastikan log worker terbaca via `kubectl logs`.
  - (Opsional) Setup Cloud Logging / Cloud Monitoring dashboard.
  - (Opsional) Cek metric Pub/Sub (unacked messages) via GCP Console.
  - Screenshot/export hasil monitoring sebagai bukti validasi.

- [ ] **5.5 — Dokumentasi Hasil Validasi**
  - Buat dokumen `VALIDATION_REPORT.md` berisi:
    - Setup yang digunakan.
    - Hasil stress test (angka, timeline, screenshot).
    - Temuan / anomali jika ada.
    - Kesimpulan apakah autoscaling berjalan sesuai PRD.

---

## Fase 6 — Clean-Up & Audit

**Objective:** Terminasi seluruh resource agar tidak ada biaya menggantung, serta audit resource idle.

### Tasks

- [ ] **6.1 — Terraform Destroy**
  - Jalankan `terraform plan -destroy` untuk review resource yang akan dihapus.
  - Jalankan `terraform destroy` untuk menghapus seluruh infrastruktur.
  - Verifikasi state file kosong / semua resource terhapus.

- [ ] **6.2 — Audit Resource Idle**
  - Cek disk yang tidak terikat:
    ```bash
    gcloud compute disks list --filter="users:-"
    ```
  - Cek forwarding rules (Load Balancer) yang masih aktif:
    ```bash
    gcloud compute forwarding-rules list
    ```
  - Cek static IP yang tidak digunakan:
    ```bash
    gcloud compute addresses list --filter="status!=RESERVED"
    ```

- [ ] **6.3 — Cleanup GCS Backend (Opsional)**
  - Hapus bucket GCS state jika proyek sudah sepenuhnya selesai.
  - Atau biarkan untuk referensi di masa depan.

- [ ] **6.4 — Cleanup Artifact Registry**
  - Hapus image container yang sudah tidak diperlukan dari Artifact Registry.
  - Atau hapus repository jika sudah tidak digunakan.

- [ ] **6.5 — Final Billing Audit**
  - Buka GCP Billing Console.
  - Verifikasi tidak ada charge berjalan dari resource proyek ini.
  - Set billing alert jika belum ada sebagai safety net.

- [ ] **6.6 — Dokumentasi Post-Mortem**
  - Tulis retrospektif di `RETROSPECTIVE.md`:
    - Apa yang berjalan lancar.
    - Tantangan yang dihadapi.
    - Lesson learned.
    - Rekomendasi improvement untuk iterasi berikutnya.

---

## Ringkasan Progress

| Fase | Deskripsi             | Status |
| :--- | :-------------------- | :----- |
| 1    | Setup Lokal & Backend | ✅     |
| 2    | Infrastructure Build  | ✅     |
| 3    | CI/CD Aplikasi        | ✅     |
| 4    | KEDA Integration      | ✅     |
| 5    | Validasi Komprehensif | ⬜     |
| 6    | Clean-Up & Audit      | ⬜     |
