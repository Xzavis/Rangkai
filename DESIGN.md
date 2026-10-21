# Rangkai — spesifikasi UI v4

Target terbaru: 16 layar mobile hasil Stitch yang sudah dirapikan dengan Impeccable. Referensi terpilih ada di [docs/ui-v4/reference](docs/ui-v4/reference/index.html); ID dan pemetaan source di [manifest](docs/ui-v4/manifest.json). Dokumen ini menggantikan aturan visual CPI v3/radius6/empat tab. Implementasi Dart saat handoff masih memakai UI sebelumnya.

## Identitas dan hierarki

Rangkai menyatukan uang, rencana, perjalanan, kalender, workspace dan absen. Bahasa UI Indonesia, kalimat singkat dan tindakan spesifik. Pertahankan nama internal Cpi* bila memperkecil perubahan. Wordmark RANGKAI dan simbol rantai adalah elemen UI. Ikon launcher folded yang sudah ada tetap terpisah; gambar mockup bukan aset adaptive launcher baru.

Satu aksi utama pada tiap konteks. Halaman Keuangan menempatkan `Tambah transaksi` dalam alur konten setelah saldo, agar tidak menutupi daftar. Gunakan jarak dan separator untuk isi satu kelompok; hindari panel dekoratif berulang, gradien, dan bayangan. Status menyertakan teks; warna saja tidak cukup.

## Token mobile light

| Peran | Nilai |
|---|---|
| Merek / fokus | #3B82F6 |
| Aksi utama / teks putih | #1D4ED8 / #FFFFFF |
| Hover/pressed utama | #1E40AF |
| Latar | #F7F8FA |
| Permukaan | #FFFFFF |
| Tinta utama | #182333 |
| Teks sekunder | #596577 |
| Border | #E2E7EE |
| Pemasukan | #03664A |
| Pengeluaran | #B42318 |
| Padding halaman dan panel | 20 logical px |
| Radius panel | 16 |
| Radius field / tombol | 12 |
| Target sentuh minimum | 44 × 44 |
| Tinggi field minimum | 48 |

Nilai mesin: [tokens.json](docs/ui-v4/tokens.json). Adapter Forui dan Material memakai token semantik bersama. Jangan mempertahankan warna tombol v3 dengan label 19px hanya untuk mengatasi kontras; target baru memakai biru aksi yang lebih gelap.

## Tipografi dan ikon

Inter untuk judul, isi, label dan nominal; gunakan tabular figures pada uang. Source Serif 4 terbatas pada sapaan Beranda. Skala logis: judul 24, bagian 18, item 15, isi 14–16, label 13, metadata 12. Biarkan TextScaler sistem bekerja, tanpa menonaktifkan skala atau mengecilkan teks demi muat. Angka uang utuh; pindahkan ke baris berikutnya bila perlu.

Referensi HTML memakai Material Symbols Outlined lokal. Di Flutter gunakan padanan outlined melalui sistem ikon yang sudah ada; jangan menampilkan nama glyph sebagai teks. Kelengkapan aset SVG saat ini perlu diperiksa (GAPS.md). Font demo tersedia di reference/assets beserta arsip notice; folder itu adalah aset dokumentasi, bukan deklarasi pubspec untuk aplikasi.

## Navigasi dan layout

Mobile memiliki lima tujuan tetap berurutan: **Beranda, Keuangan, Rencana, Kalender, Workspace**. `Cari kereta` dan `Cari hotel` berada dalam alur Rencana. Kalender dipromosikan dari panel PlansPage menjadi tujuan sendiri. Workspace tetap terlihat saat offline dengan state penjelasan dan ajakan masuk; jangan memaksa service null.

Tampilan acuan lebar 390; periksa 360 dan 430 serta teks 200%. Layout produksi tidak dibatasi ke 390/480 seperti bingkai ekspor. Pertahankan kemampuan tablet/rail source: rail mulai 720, extended mulai 960; pakai lima tujuan yang sama. Teks dan metrik reflow dengan Wrap/LayoutBuilder; jangan memberi tinggi tetap pada area teks. Form tetap dapat digulir ketika keyboard terbuka, CTA dan navigasi tidak menutupi isinya.

Gunakan SafeArea/inset platform. Status bar 09:41, sinyal, baterai dan gesture bar pada PNG hanya bingkai ilustrasi; jangan digambar sebagai widget aplikasi.

## Tema dan gerak

Tema Sistem/Terang/Gelap tetap berfungsi di semua route, modal dan picker. Paket PNG hanya menetapkan light. Palet dark yang sudah ada di lib/theme/tokens.dart merupakan baseline, bukan desain dark v4 yang telah divalidasi. Port geometri/komponen yang sama, gunakan pasangan warna tema yang sesuai dan verifikasi dark secara terpisah. Hindari pulsing dot/ping dekoratif. Hormati disableAnimations.

## Isi dan kebenaran state

Pakai `Anggaran`, `Terpakai`, `Sisa`, `Tambah transaksi`, `Buat rencana`, `Tambahkan ke rencana`, `Kirim absen` dan `Salin hasil` secara konsisten. Label formulir selalu terlihat. Tampilkan kegagalan di dekat tindakan dan pertahankan isian. Success hanya setelah operasi berhasil.

Angka dan identitas pada PNG adalah contoh; [fixtures.json](docs/ui-v4/fixtures.json) dan state layanan mengatur konsistensi data. Jarak/GPS/status foto tidak boleh dihardcode. Bedakan radius penyelesaian perjalanan yang sudah ada dari radius checkpoint absen yang belum diimplementasikan. Ikuti kontrak di GAPS.md saat referensi visual tidak sesuai kemampuan source.
