# Petunjuk agen untuk Rangkai

Baca [MUSE_HANDOFF.md](MUSE_HANDOFF.md), [DESIGN.md](DESIGN.md), dan [CONTEXT.md](CONTEXT.md) sebelum mengubah UI. Paket UI terbaru adalah **UI v4**, disiapkan 21 Oktober 2026; spesifikasi dan referensi ada di [docs/ui-v4/README.md](docs/ui-v4/README.md).

## Urutan acuan

1. Instruksi pengguna pada sesi aktif.
2. MUSE_HANDOFF.md serta kontrak perilaku pada CONTEXT.md dan kode layanan.
3. DESIGN.md, spesifikasi layar/komponen, tokens.json, fixtures.json.
4. PNG dan HTML versi terpilih pada docs/ui-v4/reference/.
5. Draf Stitch dan studi desain terdahulu adalah riwayat, bukan acuan utama.

UI v4 mengganti aturan visual v3: lima tab, padding mobile 20, card radius 16, field/button radius 12. Nama kelas internal Cpi* dapat dipertahankan. Gunakan Flutter/Forui yang sudah ada; HTML adalah referensi visual, bukan layar WebView produksi. Jangan menggambar status bar Android, baterai, atau gesture bar tiruan dari mockup.

## Kontrak yang harus dijaga

- Gerbang GPS tetap memblokir shell bila izin/layanan belum siap, termasuk dalam mode offline.
- Penyelesaian rencana: arrival <=150 m saat tracking aktif, semua rundown selesai, atau aksi manual. Riwayat transaksi tetap ada dan planId dilepas.
- Supabase tetap menjadi sumber data workspace; tulis gagal ditampilkan sebagai error, bukan keberhasilan. Tidak mengarang status tersimpan/sinkron.
- Absen memakai foto, GPS, headcount manual dan izin perwakilan per rencana; bukan pengenalan wajah. Radius checkpoint absen di mockup belum merupakan fitur source saat ini; lihat GAPS.md.
- Nama travel dari OSM; harga estimasi. Menambahkan estimasi ke rundown bukan transaksi pembayaran atau pemesanan tiket.
- Reset cloud sekarang memuat ulang server; jangan menerapkan copy reset lokal yang destruktif pada mode cloud.
- Jangan memasukkan fixture contoh ke workspace pengguna atau mengubah launcher/package ID karena logo pada mockup.

## Cara bekerja dan memverifikasi

Baca file yang diubah beserta pemanggilnya. Kerjakan sesuai urutan IMPLEMENTATION.md; lengkapi model/konversi/store/migrasi untuk field baru sebelum mengklaim form tersimpan. Jangan jalankan `forui init --force`.

Untuk paket referensi: `python3 tools/validate_ui_handoff.py`.
Untuk implementasi Flutter berikutnya: jalankan analyzer, tes yang relevan dan build setelah melengkapi prasyarat repo pada GAPS.md. Bukti browser pada browser-qa.json bukan bukti bahwa aplikasi Flutter sudah diuji atau UI v4 sudah diimplementasikan.
