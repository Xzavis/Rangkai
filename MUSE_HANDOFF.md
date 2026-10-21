# Muse Agent Code — implementasi UI baru Rangkai

Paket ini menyiapkan implementasi Flutter dari 16 layar Rangkai hasil Stitch dan refinement Impeccable (distill, clarify, polish). **Implementasi Dart belum diubah oleh handoff ini.** Versi source pada pubspec adalah 4.0.0+1; sebutan UI v4 di sini adalah target desain, bukan bukti build baru sudah tersedia.

## Prompt untuk Muse

> Implementasikan UI v4 Rangkai dengan mengikuti MUSE_HANDOFF.md, AGENTS.md dan docs/ui-v4/IMPLEMENTATION.md. Pelajari 16 PNG/HTML terpilih di docs/ui-v4/reference, gunakan DESIGN.md dan tokens.json untuk komponen Flutter/Forui. Petakan kode melalui manifest.json dan SCREENS.md. Terapkan lima tab Beranda, Keuangan, Rencana, Kalender, Workspace; travel dibuka dari Rencana. Pertahankan kontrak GPS, transaksi yang tidak ikut terhapus, cloud sync, perwakilan absen dan tema. Selesaikan gap data dan interaksi pada GAPS.md agar tidak ada field yang diam-diam dibuang atau tombol palsu. Gunakan fixtures.json hanya untuk pengujian. Jalankan validasi paket, pemeriksaan Flutter dan pengujian runtime yang relevan; laporkan bukti serta pekerjaan yang belum selesai.

## Baca dalam urutan ini

1. [Ringkasan dan indeks layar](docs/ui-v4/README.md).
2. [Arah visual terbaru](DESIGN.md), [token](docs/ui-v4/tokens.json), [komponen](docs/ui-v4/COMPONENTS.md).
3. [Spesifikasi 16 layar](docs/ui-v4/SCREENS.md) sambil membuka [galeri offline](docs/ui-v4/reference/index.html).
4. [Gap terhadap source](docs/ui-v4/GAPS.md), [urutan implementasi dan acceptance](docs/ui-v4/IMPLEMENTATION.md).
5. [Konteks layanan dan riwayat](CONTEXT.md), lalu file Dart terkait dan caller-nya.

## Definisi selesai

Semua layar benar-benar terhubung ke state dan layanan, CTA memiliki hasil yang sesuai, field baru round-trip lokal/cloud, role workspace terjaga, mode offline/cloud dibedakan, dan UI lulus pengujian ukuran kecil/besar serta teks 200%. Semua angka/status berasal dari data. UI menyerupai referensi tanpa menyalin inkonsistensi data ilustrasi atau bingkai ponselnya.

Jangan menutup pekerjaan hanya karena screenshot satu halaman sudah mirip. Jangan menyatakan backend, GPS, kamera, build atau dark mode telah diuji berdasarkan PNG/HTML. Handoff ini bukan instruksi untuk menerapkan migrasi ke backend live, merilis APK, atau mengganti ikon launcher secara otomatis.
