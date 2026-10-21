# Urutan implementasi untuk Muse

Target adalah Flutter native berbasis komponen Forui/Material yang sudah ada. Referensi HTML menjadi pedoman tampilan; tidak dimasukkan sebagai WebView. Periksa GAPS.md sebelum mengubah kode; tahap ini belum dikerjakan oleh commit handoff.

## 1. Pastikan baseline dapat diverifikasi

Baca pubspec, main, layanan yang dipanggil dan tes terkait. Pulihkan aset runtime/platform yang tidak ter-track pada baseline dengan perubahan terarah. Pastikan resolver mengenali import tema. Jalankan analyzer/test awal; catat kegagalan baseline terpisah dari kegagalan port UI. Jangan memakai output build lama sebagai bukti.

## 2. Token, komponen dan shell

Port tokens.json ke CpiTokens, FThemeData dan cpiMaterialTheme secara konsisten. Pisahkan radius card16 dan control12; tidak semua komponen memakai satu nilai radius lama. Update CpiCard/Button/Field/Reflow terlebih dahulu, termasuk warna action, tipe uang, fokus, semantics dan text scaling. Sinkronkan assets/theme.css dan test/ui_test.dart bila masih menjadi kontrak token runtime.

Ganti Shell ke lima tujuan stabil. Promosikan PlanCalendar menjadi halaman kalender yang dapat digulir; PlansPage fokus daftar rencana. Adapt WorkspacePage menjadi konten tab tanpa Scaffold/AppBar ganda; tampilkan offline state bila service null. Travel menjadi route dari Rencana dengan store/plan context. Pertahankan rail dan state pemilihan tanggal/filter/tab. GPS gate tetap berada sebelum shell.

## 3. Form dan model harus tersambung

Tambahkan kategori/note transaksi dan endDate plan melalui model, seluruh constructor/copy dalam Store, CloudSync converter, migrasi additive dan tes round-trip. Old rows tetap terbaca; field nullable/default tidak memaksa backfill data yang mengubah makna. Migration hanya disiapkan sebagai file repo; penerapan ke backend live adalah langkah terpisah.

Transaksi: jumlah>0, tanda ditentukan jenis, nama wajib, date dari picker, kategori jelas, plan opsional hanya untuk pengeluaran; note tersimpan. Save busy mencegah double submit; jika gagal field tetap ada dan pesan tampil. Tutup hanya setelah operasi sukses. Plan: validasi rentang dan koordinat tujuan pilihan OSM; mengetik teks setelah memilih tempat membatalkan pilihan koordinat lama sampai hasil dipilih lagi.

## 4. Halaman data utama dan travel

Port Beranda, Keuangan, daftar/detail rencana, kalender dan Budget & Split. Saldo, spent, remaining, agenda dan status berasal dari model/layanan. Pakai fixtures.json untuk widget/golden, bukan seed workspace pengguna. Periode/type/search memfilter daftar dan subtotal per hari; kartu `Saldo saat ini` tetap ringkasan workspace aktif, bukan saldo bulanan. Beri keterangan bahwa pemilih bulan memfilter daftar.

Travel: loading/error/no results, pilihan rute/destinasi, biaya/unit, refresh dan estimasi live tetap tersedia. Aksi Tambahkan ke rencana memilih jadwal/plan lalu menyimpan rundown estimasi melalui Store. Tidak menganggap estimasi sebagai pembayaran. Aksi salin benar-benar memakai Clipboard dan memberi feedback.

## 5. Auth, lokasi, workspace dan absen

Port Masuk/Daftar dengan busy, validasi dan backend error. Wire Lanjut offline ke root dan pertahankan retry init. Nama pengguna dari data nyata. Port permission denied, deniedForever, service off dan waiting for fix; tidak menggambar GPS aktif sebelum LocationService siap.

Workspace menggunakan role matrix dan service yang sama. Code invite berasal dari service; loading/errors ditampilkan. Kartu checkpoint/perwakilan menyatakan planId yang sedang dipakai. Untuk radius checkpoint, lengkapi model/schema/koordinat dan validasi yang disebut GAPS.md sebelum menampilkan status radius valid. Foto diambil lewat ImagePicker, headcount diisi manual, submit baru success setelah upload dan pencatatan berhasil. Tangani kondisi foto terupload tetapi bukti gagal, tanpa success palsu.

## 6. Pengaturan dan pemeriksaan akhir

Tema berubah global. Salin ringkasan memakai data aktif; logout tetap melalui AuthService dan state per-user baru. Reset lokal perlu konfirmasi; mode cloud sekarang memakai reload dengan copy berbeda. Jangan membuat reset server terselubung.

Acceptance implementasi:

- [ ] Semua 16 layar dan CTA utama dapat dicapai; Back/tab/rail tidak kehilangan state yang masih diperlukan.
- [ ] Form valid/invalid/busy/error diuji; kategori/note/endDate lolos copy dan round-trip lokal/cloud.
- [ ] Delete/complete plan dari ketiga pemicu mempertahankan semua transaksi dan melepas kaitannya.
- [ ] Target OSM, harga estimasi dan add-to-rundown bekerja tanpa pemesanan/pembayaran palsu.
- [ ] Workspace offline, loading, role terbatas, invite dan perwakilan per-plan ditangani.
- [ ] Foto belum ada, GPS belum siap, headcount salah, bukan perwakilan, radius belum diatur/di luar, upload gagal dan pencatatan gagal mempunyai hasil yang jujur.
- [ ] Tema light/dark/system, lebar360/390/430 serta320/768/1280, teks200%, keyboard dan reduced motion diuji; CTA tidak menutupi konten.
- [ ] Screenshot Flutter dibandingkan dengan PNG terpilih; status bar tiruan tidak ditiru dan selisih fixture di GAPS.md dipahami.

Pemeriksaan saat implementasi:

```sh
python3 tools/validate_ui_handoff.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Tes perilaku yang relevan: test/budget_test.dart, calendar_test.dart, sync_test.dart, workspace_test.dart, attendance_test.dart, auth_test.dart dan ui_test.dart. Perbarui ekspektasi visual/token yang memang diganti; jangan menghapus assertion bisnis untuk membuat port lolos. Tambahkan tes berarti untuk field baru, izin, filtering dan geofence yang benar-benar diimplementasikan. Bukti GPS, kamera dan backend memerlukan pengujian runtime yang sesuai, tidak digantikan browser QA.

Laporan akhir implementasi harus menyebut file yang berubah, perilaku utama, perintah yang dijalankan dan hasilnya. Jika ada kendala build/runtime, tulis apa yang belum dibuktikan. Rilis APK, penerapan migrasi live dan penggantian launcher tidak termasuk tindakan otomatis dari handoff ini.
