# AGENT.md — Playbook agen AI untuk Rangkai

Dokumen ini playbook operasional untuk agen AI (Muse, Claude Code, Codex,
dan sejenisnya) yang bekerja di repo ini. Aturan kanonik yang mengikat ada
di [AGENTS.md](AGENTS.md). Bila isi dokumen ini bertabrakan dengan
AGENTS.md, instruksi pengguna di sesi aktif, atau kontrak di
[CONTEXT.md](CONTEXT.md) dan kode layanan, yang menang adalah acuan
dengan urutan lebih tinggi di AGENTS.md. Untuk kolaborator manusia,
mulailah dari [README.md](README.md).

## Baca dulu, baru ubah

1. Instruksi pengguna pada sesi aktif.
2. [MUSE_HANDOFF.md](MUSE_HANDOFF.md), kontrak perilaku di
   [CONTEXT.md](CONTEXT.md) dan kode layanan terkait.
3. [DESIGN.md](DESIGN.md), spesifikasi layar/komponen,
   [docs/ui-v4/tokens.json](docs/ui-v4/tokens.json),
   [docs/ui-v4/IMPLEMENTATION.md](docs/ui-v4/IMPLEMENTATION.md),
   [docs/ui-v4/GAPS.md](docs/ui-v4/GAPS.md).
4. PNG dan HTML terpilih di `docs/ui-v4/reference/` untuk layar yang diubah.
   Buka gambarnya, jangan menebak dari nama file.
5. File yang akan diubah beserta pemanggil dan tesnya. Hasil search hanya
   menemukan kandidat; perilaku dibuktikan dari isi file yang dibaca.

## Cara bekerja

- Kerjakan perubahan sekecil mungkin yang menyelesaikan Issue/PR yang
  ditugaskan. Jangan menambah fitur, layar, kontrol, atau dependensi yang
  tidak diminta.
- Ikuti urutan `docs/ui-v4/IMPLEMENTATION.md`. Field data baru wajib
  lengkap dulu di model, konversi, store, dan migrasi Supabase sebelum
  form diklaim bisa menyimpan.
- Samakan bentuk API dengan kode tetangga yang sudah ada (tipe, nama,
  pola error, kelas `Cpi*`). Pakai Flutter/Forui existing. Jangan
  menjalankan `forui init --force`.
- UI mengikuti token v4: padding mobile 20, radius card 16, radius
  field/button 12, target sentuh minimum 44. Layout harus reflow mengikuti
  lebar dan skala teks; jangan kunci tinggi sel grid sampai label overflow.
- Jangan menggambar status bar Android, baterai, atau gesture bar tiruan
  dari mockup. HTML referensi bukan WebView produksi.
- Angka dan status di UI dari data nyata (Store/Supabase/OSM/GPS).
  Dilarang mengarang saldo, status tersimpan/tersinkron, atau data contoh
  yang masuk workspace pengguna.
- File besar ditulis bertahap, bukan satu tulis raksasa.

## Kontrak yang tidak boleh dilanggar agen

- Gerbang GPS tetap memblokir shell bila izin/layanan lokasi belum siap,
  termasuk offline.
- Penyelesaian rencana: tiba <= 150 m saat tracking aktif, semua rundown
  selesai, atau aksi manual. Riwayat transaksi tetap ada, `planId` dilepas.
- Supabase sumber data workspace. Tulis gagal ditampilkan sebagai error.
- Absen: foto, GPS, headcount manual, izin perwakilan per rencana.
  Bukan pengenalan wajah. Radius checkpoint belum fitur; jangan tampilkan
  badge radius seolah sudah jalan.
- Travel: nama dari OSM, harga estimasi. Tambah estimasi ke rundown bukan
  pembayaran/pemesanan.
- Reset cloud memuat ulang server. Jangan terapkan copy reset lokal
  destruktif pada mode cloud.
- Jangan mengubah launcher/package ID karena logo mockup.

## Rahasia dan konfigurasi backend

- Konfigurasi app hanya lewat `--dart-define-from-file=dart_define.json`
  (salin dari `dart_define.example.json`). File `dart_define.json` dan
  `.env` gitignored dan tidak boleh di-commit, ditempel di PR, issue,
  log, atau screenshot.
- Hanya anon/publishable key (`sb_publishable_...`) yang boleh masuk
  build. App menolak JWT `service_role` dan `sb_secret_...` di
  `lib/auth.dart` (`BackendConfig.isServiceRoleKey`). Jangan melemahkan
  penolakan ini.
- Jangan mencetak nilai kunci, token sesi, atau password akun uji di
  output. Laporkan status (200/401), bukan isi header Authorization.
- Tes tulis ke backend live memakai akun sekali pakai
  (`integration_test/backend_e2e_test.dart`), bukan akun pribadi
  pengguna. Probe ke akun nyata bersifat baca saja, kecuali pengguna
  meminta lain di sesi itu.

## Verifikasi wajib sebelum mengaku selesai

Jalankan dan laporkan output nyatanya, bukan ringkasan karangan:

```powershell
flutter analyze
flutter test
```

- Perubahan perilaku atau perbaikan bug wajib menambah/memperbarui tes
  terkecil yang relevan di `test/` (atau `integration_test/` bila butuh
  device/backend). Tes harus bisa gagal bila perilakunya rusak lagi.
- Jangan melewati tes yang gagal dengan skip, deselect, atau mengubah
  ekspektasi agar cocok dengan kode. Bila kontrak memang berubah (misal
  copy mengikuti referensi UI v4), jelaskan sumber kontrak barunya.
- Klaim selesai hanya untuk yang benar-benar diamati: analyzer bersih,
  tes hijau, APK ter-build, atau layar terlihat di screenshot. Pisahkan
  dengan jelas antara "terverifikasi", "disimpulkan dari kode", dan
  "belum diverifikasi".
- `python tools/validate_ui_handoff.py` memvalidasi paket referensi,
  bukan aplikasi Flutter. Saat dokumen ini ditulis validator masih
  gagal karena EOL/manifest di checkout Windows. Laporkan apa adanya;
  jangan regenerasi manifest tanpa keputusan owner.

### E2E device (USB)

```powershell
adb devices -l
flutter test integration_test/app_e2e_test.dart -d <deviceId>
flutter test integration_test/backend_e2e_test.dart -d <deviceId> `
  --dart-define-from-file=dart_define.json
```

- HP fisik butuh izin lokasi granted dan GPS memperoleh fix. Shell
  `pm grant` bisa ditolak OEM; minta pengguna memberi izin dari dialog.
- Pemindai install Realme/Oppo ("Dari Shell"): tap "Instal" di HP.
- Integration test menimpa `build/app/outputs/flutter-apk/app-debug.apk`
  dengan APK harness test dan bisa meng-uninstall app sesudahnya.
  Build ulang `flutter build apk` sebelum install manual atau demo.
- Jangan mematikan proses/device pengguna yang tidak kamu mulai.
  Berhenti dan laporkan bila device hilang dari `adb devices`.

## Alur kontribusi agen di GitHub

1. Ambil satu Issue. Bila belum ada, usulkan isinya mengikuti format
   fitur di README (masalah, referensi layar, kebutuhan data, kriteria
   selesai, dampak kontrak). Jangan mengarang fitur di luar penugasan.
2. Branch `feat/<singkat>` / `fix/<singkat>` / `docs/<singkat>` dari
   `main`. Jangan push langsung ke `main`.
3. Commit hanya file yang kamu ubah dan bisa kamu jelaskan. Jangan
   `git add -A` di tree kotor. Jangan commit APK, `build/`, `outputs/`,
   screenshot pribadi, `.env`, atau `dart_define.json`.
4. Commit, push, merge, tag, dan rebase hanya bila pengguna/owner
   memintanya secara eksplisit di sesi itu.
5. Deskripsi PR memuat: masalah, daftar file berubah, bukti perintah
   (analyze/test/build/device) dengan hasil sebenarnya, screenshot
   untuk perubahan UI, dan sisa yang belum diverifikasi.
6. Jangan menulis ulang riwayat git (`reset --hard`, amend commit orang,
   force push) tanpa perintah eksplisit owner.

## Definition of done

- [ ] Acuan yang relevan sudah dibaca (termasuk gambar referensi layar).
- [ ] Perubahan sekecil mungkin; kontrak perilaku tidak dilanggar.
- [ ] `flutter analyze` bersih untuk kode yang disentuh.
- [ ] Tes relevan hijau; tes regresi ditambah untuk bug/perilaku baru.
- [ ] Klaim visual didukung screenshot/golden, atau dinyatakan belum
      terverifikasi. Tidak ada klaim pixel-perfect tanpa render.
- [ ] Tidak ada rahasia, APK, atau file hasil generate yang ikut commit.
- [ ] Laporan akhir menyebut file berubah, bukti tes, dan utang yang sisa.
