# Product Requirements Document (PRD): Project AeroScale

**Nama Proyek:** Project AeroScale  
**Status:** Final  
**Pemilik Proyek:** Stayrelevant.id  
**Tujuan:** Membangun infrastruktur GKE otomatis dengan autoscaling berbasis event menggunakan KEDA dan GCP Pub/Sub.

---

## 1. Deskripsi Proyek

Project AeroScale adalah inisiatif pembelajaran untuk mengimplementasikan sistem _event-driven autoscaling_ pada aplikasi Golang. Sistem ini akan secara dinamis menyesuaikan jumlah pod berdasarkan beban antrian di GCP Pub/Sub guna mengoptimalkan performa dan efisiensi biaya operasional.

---

## 2. Arsitektur Operasional & State Management

- **Terraform (Local Execution):** Seluruh perintah `init`, `plan`, `apply`, dan `destroy` dilakukan secara lokal untuk kendali penuh dan keamanan.
- **Remote Backend:** State Terraform disimpan secara persisten di **Google Cloud Storage (GCS) Bucket** agar data tetap sinkron meskipun berpindah perangkat pengerjaan.
- **CI/CD Pipeline (Automated):** Otomatisasi hanya difokuskan pada aplikasi, mencakup:
  - Build Docker image (Golang).
  - Push ke Google Artifact Registry.
  - Update deployment ke cluster GKE.

---

## 3. Spesifikasi Infrastruktur (Terraform)

| Komponen         | Spesifikasi & Konfigurasi                                          |
| :--------------- | :----------------------------------------------------------------- |
| **Cluster GKE**  | Standard Zonal Cluster dengan Workload Identity aktif.             |
| **Node Pool**    | Managed Default Node Pool (Min 1, Max 3 Nodes), Tipe: `e2-medium`. |
| **Autoscaler**   | KEDA Operator diinstal via Helm Provider melalui Terraform lokal.  |
| **Event Source** | GCP Pub/Sub Topic & Subscription.                                  |

---

## 4. Logika Autoscaling (KEDA)

- **Trigger:** `gcp-pubsub`.
- **Threshold:** **50 pesan** (1 pod tambahan dibuat setiap kelipatan 50 pesan tertunda dalam antrian).
- **Kebijakan Replika:**
  - **Minimum Pod:** 1 (Menjamin aplikasi selalu siap sedia/no cold start).
  - **Maximum Pod:** 10 (Batas keamanan biaya).

---

## 5. Roadmap Eksekusi

1.  **Fase 1 (Setup Lokal & Backend):** Membuat bucket GCS manual dan konfigurasi `backend "gcs"` pada Terraform.
2.  **Fase 2 (Infrastructure Build):** Eksekusi `terraform apply` lokal untuk membangun VPC, GKE, dan Pub/Sub.
3.  **Fase 3 (CI/CD Aplikasi):** Setup pipeline GitHub Actions/GitLab CI untuk build-to-deploy worker Golang.
4.  **Fase 4 (KEDA Integration):** Deployment `ScaledObject` dan IAM binding identitas pod ke Pub/Sub.
5.  **Fase 5 (Validasi Komprehensif):** Stress test 500 pesan, analisis HPA, dan monitoring log secara real-time.
6.  **Fase 6 (Clean-Up & Audit):** Terminasi total via `terraform destroy` dan audit resource idle.

---

## 6. Manajemen Biaya & Clean-Up (Fase 6 Detail)

Untuk memastikan tidak ada biaya yang menggantung, prosedur berikut wajib dijalankan secara lokal:

### Audit Resource Idle

Gunakan perintah `gcloud` untuk mengecek resource yang mungkin tidak terhapus otomatis:

```bash
# Cek disk yang tidak terikat ke VM manapun
gcloud compute disks list --filter="users:-"

# Cek Forwarding Rules (Load Balancer) yang masih aktif
gcloud compute forwarding-rules list

# Cek Static IP yang tidak digunakan
gcloud compute addresses list --filter="status!=RESERVED"
```
