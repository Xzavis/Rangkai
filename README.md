# Rangkai — Semua terangkai.

App Flutter Android: keuangan, rencana dan rundown manual, budget vs realisasi, GPS realtime wajib, pencarian hotel dan stasiun asli dari peta. Source memakai Forui dan Material dengan tema light/dark. `pubspec.yaml` saat handoff: 4.0.0+1. Desain UI v4 baru tersedia sebagai paket referensi untuk implementasi.

## UI baru untuk Muse Agent Code

Mulai dari **[MUSE_HANDOFF.md](MUSE_HANDOFF.md)** dan [AGENTS.md](AGENTS.md). Paket berisi16 PNG/HTML final, token, fixture konsisten, pemetaan ke source Flutter, gap data/layanan dan urutan acceptance implementasi.

- [Galeri referensi offline](docs/ui-v4/reference/index.html) · [Indeks dan spesifikasi](docs/ui-v4/README.md).
- [Arah desain terbaru](DESIGN.md) · [Rencana implementasi](docs/ui-v4/IMPLEMENTATION.md) · [Gap terhadap source](docs/ui-v4/GAPS.md).
- Validasi paket: `python3 tools/validate_ui_handoff.py`.

**Status:** paket UI sudah disiapkan; Dart belum dipindahkan ke UI baru dan tidak ada build APK baru dari handoff ini. Bagian "UI versi3" di bawah adalah riwayat baseline. Aturan visual terbaru memakai lima tab dan radius16/12, bukan empat tab/radius6. Kontrak layanan tetap berlaku.

GitHub menampilkan source HTML. Checkout/download repo lalu buka galeri lokal untuk pratinjau offline. Tidak perlu menyalin file dari folder Download pribadi agar Muse bisa membaca referensi.

## Jalanin dari source

Butuh Flutter >=3.47, Dart >=3.13, dan JDK 17 atau yang kompatibel dengan Gradle proyek.

```powershell
cd cpi
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Jalanin dengan backend (workspace + absen)

Tanpa ini app jalan mode lokal. Dengan ini: login, workspace berbagi, absen tim.

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://xyz.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
```

Skema database: `supabase/migrations/001_workspaces.sql` + `002_reps.sql` +
`003_storage.sql` (jalankan berurutan di SQL Editor). Foto absen memakai
Supabase Storage bucket `absensi` — tanpa konfigurasi tambahan.

APK hasil build: `build/app/outputs/flutter-apk/app-release.apk`.

## Sistem UI versi 3 — riwayat sebelum port v4

- Arahan desain dan layout: [DESIGN.md](DESIGN.md).
- CSS light/dark: [assets/theme.css](assets/theme.css). Flutter menggunakan padanan
  token pada `lib/theme/tokens.dart`; tes memastikan seluruh nilai warna cocok.
- `forui.yaml` dan `lib/theme/` berasal dari `dart run forui --no-input init`.
  CLI mempertahankan `main.dart` yang sudah ada; integrasi root dilakukan manual.
  Jangan gunakan `--force` pada init untuk aplikasi ini.
- Komponen bersama: `CpiCard`, `CpiButton`, `CpiField`, `CpiReflow` dan `CpiContent`.
- Pengaturan menyediakan mode Sistem/Terang/Gelap. Font Inter, JetBrains Mono,
  dan Source Serif 4 dibundel beserta lisensi OFL di `assets/fonts/`.
- APK lama tetap merupakan rilis lama. Perubahan UI tersedia dalam build source
  3.0.0+4; menambahkan package tidak mengubah APK yang sudah dikompilasi.

## Cara pakai versi 3

1. Buka app. GPS wajib aktif: kalau layanan lokasi mati atau izin ditolak, app berhenti di gerbang GPS sampai lokasi aktif dan izin diberikan.
2. Tab Rencana, tap `+ Rencana`: isi nama, cari tempat tujuan, pilih satu hasil pencarian supaya koordinatnya terkunci, isi budget dan tanggal.
3. Buka detail rencana: tambah dan hapus rundown sendiri, centang yang selesai, kaitkan pengeluaran dari tab Keuangan.
4. Tekan `Mulai tracking`: jarak GPS ke tujuan dihitung realtime. Pada jarak 150 meter atau kurang, rencana otomatis selesai dan dihapus. Tombol `Selesaikan dan hapus` melakukan hal yang sama secara manual. Semua rundown dicentang juga memicu penyelesaian otomatis. Transaksi terkait tidak ikut terhapus.
5. Tab Travel: ketik kota tujuan, tekan `Cari kereta` atau `Cari hotel`. Nama stasiun dan hotel diambil live dari OpenStreetMap. Harga adalah estimasi yang bergerak tiap 8 detik, bukan tarif resmi penjual tiket.

## Batasan yang ditulis apa adanya

- Tidak ada template destinasi. Semua rencana dan rundown dibuat pengguna sendiri.
- Nama tempat dari OpenStreetMap bisa tidak lengkap untuk daerah yang datanya jarang.
- Harga travel adalah estimasi live karena tarif resmi KAI dan hotel butuh API penjual berizin/kunci API.
- Data masih in-memory dan reset saat app ditutup. Itu batas berikutnya kalau butuh persistensi.
