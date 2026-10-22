# Rangkai — Semua terangkai.

App Flutter Android untuk mengelola keuangan, rencana perjalanan + rundown,
budget vs realisasi, absen tim berbasis foto+GPS, dan workspace berbagi.
GPS aktif adalah syarat masuk app (gerbang GPS), nama tempat dari
OpenStreetMap, backend Supabase (Auth, Postgres + RLS, Storage).

Dokumen ini untuk **kontributor manusia**. Agen AI wajib membaca
[AGENTS.md](AGENTS.md) (aturan kanonik) dan [AGENT.md](AGENT.md)
(playbook operasional) sebelum menulis kode.

## Status terverifikasi (22 Oktober 2026)

- UI v4 (5 tab, padding 20, card radius 16, field/button radius 12) sudah
  diimplementasikan di Flutter/Forui dari [docs/ui-v4](docs/ui-v4/README.md).
- Frontend–backend tersambung: login, workspace, invite/join, dan sync
  transaksi terbukti lewat E2E backend live di HP fisik.
- Gerbang kualitas terakhir: `flutter analyze` bersih, `flutter test`
  46/46 hijau, E2E offline + E2E backend hijau di device USB.
- Yang masih kurang dicatat jujur di [docs/ui-v4/GAPS.md](docs/ui-v4/GAPS.md)
  dan bagian "Batasan & gap terbuka" di bawah. Jangan klaim lebih dari bukti.

## Arsitektur ringkas

| Lapisan | Isi |
|---|---|
| UI | Flutter + Forui, tema light/dark, token di `lib/theme/`, komponen bersama `lib/components.dart` + `lib/widgets.dart` (kelas internal `Cpi*`) |
| Layar | `lib/pages.dart` (Beranda/Keuangan/Rencana/Kalender/Travel/Split), `lib/main.dart` (shell 5 tab, gerbang GPS, Pengaturan), `lib/login_page.dart`, `lib/workspace_page.dart`, `lib/absen.dart`, `lib/calendar.dart` |
| State & layanan | `lib/core.dart` (model + Store), `lib/auth.dart` (konfigurasi backend + AuthService), `lib/sync.dart` (CloudSync), `lib/workspace.dart` (WorkspaceService) |
| Backend | Supabase: Auth email/password, tabel `workspaces`, `memberships`, `invites`, `plans`, `rundowns`, `transactions`, `checkpoints`, `attendance`; skema di `supabase/migrations/`; foto absen di Storage bucket `absensi` |
| Peta | OpenStreetMap (nama stasiun/hotel live). Harga travel = estimasi, bukan tarif resmi dan bukan pemesanan tiket |

## Prasyarat

- Flutter >= 3.47, Dart >= 3.13, JDK 17 (atau yang kompatibel dengan Gradle proyek).
- Android SDK + device/emulator untuk E2E (`adb` di PATH atau dari Android SDK).
- Untuk mode backend: proyek Supabase sendiri (jangan pakai kredensial orang).

## Setup

```powershell
git clone https://github.com/Xzavis/Rangkai.git
cd Rangkai
flutter pub get
flutter analyze
flutter test
```

### Konfigurasi backend (wajib untuk login/workspace/absen)

1. Jalankan migrasi **berurutan** di Supabase SQL Editor:
   `001_workspaces.sql`, `002_reps.sql`, `003_storage.sql`,
   `004_tx_category_plan_range.sql`, `005_security_hardening.sql`,
   `006_create_workspace_rpc.sql`.
2. Salin `dart_define.example.json` menjadi `dart_define.json`, isi URL
   proyek (`https://<ref>.supabase.co`) dan **anon/publishable key**
   (`sb_publishable_...`). File ini gitignored — jangan di-commit.
3. Jalankan dengan define:

```powershell
flutter run --dart-define-from-file=dart_define.json
flutter build apk --release --dart-define-from-file=dart_define.json
```

Tanpa `dart_define.json`, app tetap jalan mode lokal (offline) dan
menampilkan halaman petunjuk backend — itu perilaku sengaja, bukan crash.

**Keamanan:** hanya anon/publishable key yang boleh masuk app. App menolak
JWT `service_role` dan kunci `sb_secret_...`. Jangan pernah commit `.env`,
`dart_define.json`, service_role/secret key, password akun, atau APK hasil
build ke repo.

## Testing

Wajib hijau sebelum PR dibuka:

```powershell
flutter analyze
flutter test
```

E2E di HP fisik lewat USB (perlu izin lokasi granted + GPS dapat fix):

```powershell
# Alur offline: gerbang GPS -> 5 tab -> tambah transaksi
flutter test integration_test/app_e2e_test.dart -d <deviceId>

# Backend live: signup -> workspace -> invite/join -> sync (akun sekali pakai)
flutter test integration_test/backend_e2e_test.dart -d <deviceId> `
  --dart-define-from-file=dart_define.json
```

Catatan E2E yang menghemat waktu:

- `adb devices -l` dulu. HP Realme/Oppo menampilkan pemindai install
  "Dari Shell"; tap "Instal" di HP agar test lanjut.
- `flutter test` integration menimpa `build/app/outputs/flutter-apk/app-debug.apk`
  dengan APK test. Jangan install file itu manual sebagai app biasa,
  build ulang dengan `flutter build apk` dulu.
- E2E backend skip dengan pesan bila define kosong. Skip bukan hijau.
- `python tools/validate_ui_handoff.py` saat ini masih gagal di checkout
  Windows karena EOL/manifest referensi. Status terakhir dan keputusan
  perbaikannya dicatat di handoff, jangan regenerasi manifest diam-diam.

## Kolaborasi di GitHub

Repo: https://github.com/Xzavis/Rangkai. Branch utama: `main`.

1. Bikin Issue dulu untuk fitur/perubahan perilaku. Satu Issue, satu tujuan.
2. Branch dari `main` terbaru: `feat/<nama-singkat>`, `fix/<nama-singkat>`,
   atau `docs/<nama-singkat>`. Jangan push langsung ke `main`.
3. Kerjakan sekecil mungkin sesuai urutan
   [docs/ui-v4/IMPLEMENTATION.md](docs/ui-v4/IMPLEMENTATION.md).
4. Buka Pull Request ke `main`. Isi: masalah, perubahan, bukti perintah
   (`flutter analyze` + tes yang relevan, tempel ringkasan outputnya),
   dan screenshot sebelum/sesudah untuk perubahan UI.
5. PR di-merge hanya bila analyzer + tes hijau dan review menyetujui.
   Tes yang gagal tidak boleh di-skip, di-deselect, atau diubah
   ekspektasinya agar cocok dengan kode, kecuali kontraknya memang
   berubah dan perubahan itu dijelaskan di PR.
6. Pesan commit singkat dan jelas, ikuti gaya riwayat repo
   (contoh: `Fix stuck logo: ...`, `docs: ...`).

### Mengusulkan fitur yang kamu inginkan

Siapa pun boleh mengusulkan fitur lewat Issue. Agar bisa langsung
dikerjakan manusia atau agen, usulan wajib memuat:

- Masalah pengguna yang diselesaikan (bukan sekadar "tambah halaman X").
- Layar referensi UI v4 terkait (nomor file di `docs/ui-v4/reference/`),
  atau sketsa bila layar baru.
- Data yang dibutuhkan: field baru berarti model, konversi, store, dan
  migrasi Supabase harus lengkap sebelum form diklaim tersimpan.
- Kriteria selesai yang bisa dites, termasuk state kosong/error/offline.
- Dampak ke kontrak perilaku di bawah. Fitur yang melanggar kontrak
  ditolak atau didesain ulang, bukan diakali.

### Kontrak perilaku (jangan dilanggar)

Detail kanonik di [CONTEXT.md](CONTEXT.md) dan [AGENTS.md](AGENTS.md).
Ringkasnya:

- Gerbang GPS memblokir shell bila izin/layanan lokasi belum siap,
  termasuk saat offline.
- Rencana selesai bila: tiba <= 150 m saat tracking aktif, semua rundown
  selesai, atau aksi manual. Transaksi riwayat tetap ada, `planId` dilepas.
- Supabase adalah sumber data workspace. Tulis yang gagal ditampilkan
  sebagai error, bukan keberhasilan. Tidak mengarang status
  tersimpan/tersinkron.
- Absen memakai foto, GPS, headcount manual, dan izin perwakilan per
  rencana. Bukan pengenalan wajah.
- Nama travel dari OpenStreetMap, harga berupa estimasi. Menambahkan
  estimasi ke rundown bukan pembayaran atau pemesanan tiket.
- Reset pada mode cloud memuat ulang data server, bukan reset lokal
  destruktif.
- Data fixture contoh tidak dimasukkan ke workspace pengguna. Launcher
  dan package ID tidak diubah hanya karena logo di mockup.
- Jangan jalankan `forui init --force`.

### Aturan UI

- Ikuti token dan referensi UI v4: 5 tab, padding mobile 20, radius card
  16, radius field/button 12, target sentuh minimum 44.
- HTML di `docs/ui-v4/reference/` adalah referensi visual, bukan layar
  WebView produksi.
- Jangan menggambar status bar Android, baterai, atau gesture bar tiruan.
- Tile/grid harus tumbuh mengikuti konten dan skala teks. Jangan kunci
  tinggi sel grid dengan rasio tetap sampai label overflow.
- Angka, saldo, dan status di UI harus dari data nyata. State kosong
  menjelaskan sebab dan aksi berikutnya.

## Batasan & gap terbuka

- Belum ada golden/screenshot test Flutter vs PNG referensi 01-15.
  Kesesuaian visual saat ini dibuktikan widget test struktur + review
  screenshot device, belum pixel-perfect.
- Validator handoff masih merah untuk EOL/manifest (lihat Testing).
- Travel belum punya kontrol asal/tanggal/penumpang sebagai state
  pencarian. Radius checkpoint absen di mockup belum jadi fitur
  (belum ada model, migrasi, editor).
- Form tambah transaksi dan buat rencana masih bottom sheet.
- Runtime GPS/kamera di emulator butuh geo fix; bukti yang ada memakai
  HP fisik.

## Peta dokumen

- [MUSE_HANDOFF.md](MUSE_HANDOFF.md): titik mulai implementasi UI v4.
- [DESIGN.md](DESIGN.md), [docs/ui-v4/README.md](docs/ui-v4/README.md),
  [docs/ui-v4/tokens.json](docs/ui-v4/tokens.json): arah dan token desain.
- [CONTEXT.md](CONTEXT.md): kontrak perilaku produk.
- [AGENTS.md](AGENTS.md) dan [AGENT.md](AGENT.md): aturan + playbook agen AI.
- [docs/vision_windows.md](docs/vision_windows.md): tool screenshot/tap
  device lewat ADB untuk verifikasi visual.
- Riwayat UI versi 3 ada di git history sebelum port v4. Jangan jadikan
  acuan visual baru.
