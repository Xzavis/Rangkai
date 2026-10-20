# Fitur CPI (Cash, Plan & Itinerary) — Versi 3.0.0

Dokumen ini menjabarkan seluruh fitur, arsitektur antarmuka, dan kapabilitas sistem pada **CPI Versi 3.0.0** (`v3.0.0+4`).

---

## 1. Desain Antarmuka & Sistem Visual (Forui + Material 3)

Versi 3 membawa perombakan total pada sistem visual menggunakan pendekatan hibrida **Forui UI (`forui: ^0.27.6`)** dan **Material 3 (`useMaterial3: true`)**:

- **Token Desain Terpadu**:
  - Didefinisikan lintas platform di `assets/theme.css` dan diimplementasikan di `lib/theme/tokens.dart` (`CpiTokens`).
  - Palet warna eksak: Primary Blue (`#3b82f6`), Dark Background (`#171717`), Light Background (`#ffffff`), Destructive Red (`#ef4444`).
  - Radius sudut konsisten: dasar `6.0` px (`0.375rem`) untuk Card, Field, dan Button; `12.0` px untuk Bottom Sheet modal.
- **Tipografi Offline Terintegrasi**:
  - **Inter**: Teks antarmuka, judul, dan angka nominal umum.
  - **JetBrains Mono**: Jam realtime, koordinat lintang/bujur GPS, dan data tabular (`fontFeatures: [FontFeature.tabularFigures()]`).
  - **Source Serif 4**: Aksen editorial dan token serif.
- **Aksesibilitas & Kontras Warna**:
  - Memenuhi batas ambang kontras WCAG (3:1 untuk teks besar, 4.5:1 untuk teks biasa).
  - Teks tombol aksi utama berukuran 19px tebal (`FontWeight.w700`) di atas warna primary (`#3b82f6`).
  - Penanganan error kontras adaptif: merah gelap `#b91c1c` pada mode terang, merah lembut `#fca5a5` pada mode gelap.
  - Ukuran target sentuh minimal 44×44 px / 48 px tinggi tombol.
- **Dukungan Pengurangan Gerakan (`prefers-reduced-motion`)**:
  - Semua animasi (`AnimatedMoney`, `BudgetRing`, transisi tab `AnimatedSwitcher`, progress bar) mendeteksi `MediaQuery.disableAnimationsOf(context)` dan beralih ke `Duration.zero`.
- **Indikator Live Statis (`LiveDot`)**:
  - Titik visual 8px tanpa animasi denyut (pulsing loop) konstan guna menghemat baterai perangkat dan mencegah distraksi visual.

---

## 2. Tata Letak Responsif & Adaptif (Multi-Screen Breakpoints)

CPI v3 beradaptasi mulus dari layar HP kecil hingga tablet/desktop:

- **Layar Mobile (<600 px)**:
  - Tata letak 1 kolom dengan padding tepi 16 px.
  - Navigasi bawah (`NavigationBar`) dengan 4 tujuan utama.
- **Layar Menengah (600–719 px)**:
  - Padding diperlebar ke 24 px dengan pembatas konten maksimal 880 px (`CpiContent`).
- **Layar Tablet & Desktop (>=720 px & >=960 px)**:
  - Navigasi otomatis bertransisi menjadi `NavigationRail` di sisi kiri.
  - Pada lebar >=960 px, rel samping diperluas (`extended`) menampilkan label teks lengkap, serta batas lebar konten menjadi 1120 px.
- **Komponen Penyesuai Tata Letak (`CpiReflow`)**:
  - Secara otomatis mengubah susunan baris (*Row*) menjadi kolom (*Column*) apabila lebar kontainer kurang dari 440 px atau pengguna mengaktifkan pembesaran teks aksesibilitas sistem (`textScaler > 22`).

---

## 3. Fitur Utama Per Halaman

### A. Beranda (Home)
- **Jam Realtime Multi-Zona**:
  - Tampilan jam digital monospaced (`JetBrains Mono`) sinkron detik demi detik.
  - Pilihan cepat 7 zona waktu dunia (WIB UTC+7, WITA UTC+8, WIT UTC+9, SGT UTC+8, JST UTC+9, GST UTC+4, GMT UTC+0).
- **Status GPS Realtime**:
  - Menampilkan koordinat langsung lintang dan bujur beserta estimasi akurasi dalam meter.
- **Ringkasan Saldo Cepat**:
  - Nominal saldo dinamis dengan efek count-up (`AnimatedMoney`).
  - Tombol **Salin Ringkasan**: menyalin format ringkasan keuangan siap kirim ke clipboard (misal ke WhatsApp/Catatan).
- **Kartu Budget Rencana Aktif**:
  - Menampilkan rencana terdekat dengan diagram cincin rasio anggaran (`BudgetRing`).
  - Otomatis berubah warna menjadi warna error bila pengeluaran melebihi anggaran (>= 100%).
- **Daftar Transaksi Terakhir**:
  - Menampilkan 3 transaksi terbaru dengan ikon SVG custom.

### B. Keuangan (Finance)
- **Pencarian Transaksi**: Filter realtime berdasarkan nama/catatan transaksi.
- **Metrik Saldo & Aliran Kas**: Pemisahan jelas total pemasukan dan total pengeluaran.
- **Manajemen Transaksi**:
  - Modal tambah transaksi (`showTxSheet`) dengan pemilih jenis (*Pengeluaran* / *Pemasukan*).
  - Opsi penautan transaksi pengeluaran langsung ke rencana perjalanan tertentu (`planId`).
  - Hapus transaksi mudah dengan aksi tekan lama (*long press*).

### C. Rencana & Rundown Acara (Plans & Detail)
- **Pembuatan Rencana Terintegrasi Peta**:
  - Form nama acara, budget, dan tanggal pelaksanaan.
  - **Integrasi Nominatim OpenStreetMap**: Pencarian lokasi langsung dari peta dunia, mengunci koordinat latitude dan longitude tujuan secara presisi.
- **Rundown Acara Fleksibel**:
  - Penambahan jadwal per jam (`HH:mm`), nama agenda, dan estimasi biaya per rundown.
  - Urutan rundown otomatis tersortir kronologis berdasarkan waktu.
  - Pelacakan status rundown aktif berdasarkan jam sistem saat ini (`activeRundown`).
- **Pelacakan Perjalanan GPS Asli (Live Tracking)**:
  - Perhitungan jarak sisa dari posisi fisik ponsel ke koordinat tujuan secara realtime via Geolocator.
  - Baris progres perjalanan (`tripProgress`) dari jarak awal keberangkatan.
- **3 Mekanisme Penyelesaian Rencana (Auto-Completion)**:
  1. **Radius GPS <= 150 Meter**: Begitu pengguna tiba dalam jarak 150 meter dari titik tujuan, rencana otomatis diselesaikan dan dihapus dari daftar aktif.
  2. **Penyelesaian Rundown**: Menandai seluruh rundown sebagai selesai otomatis memicu penyelesaian rencana.
  3. **Penyelesaian Manual**: Tombol "Selesaikan dan hapus".
  - *Catatan Penting*: Transaksi keuangan yang tertaut pada rencana **TIDAK** terhapus saat rencana selesai, melainkan ikatannya dilepas (`planId = null`) sehingga buku kas tetap akurat.

### D. Travel Live (Pencarian & Estimasi Harga)
- **Pencarian Fasilitas Asli OpenStreetMap (OSM)**:
  - Pencarian stasiun kereta dan hotel di sekitar kota tujuan via Overpass API dan Nominatim.
  - Nama tempat, jalan, dan kelas bintang hotel adalah data asli peta dunia.
- **Fluktuasi Harga Estimasi Live**:
  - Simulasi pergerakan harga tiket kereta dan tarif hotel per malam setiap 8 detik (`_tick`).
  - Penanda delta harga (`+Rp...` atau `-Rp...`) untuk memantau dinamika estimasi.
- **Filter & Pengurutan**:
  - Tab filter: *Semua*, *Kereta*, dan *Hotel*.
  - Opsi filter cerdas: *Paling murah dulu* (urut harga terendah).
  - Tarik ke bawah untuk memuat ulang (*Pull-to-refresh*).

### E. Pengaturan & Personalisasi (Settings)
- **Pemilih Tema Global**:
  - Pilihan mode: **Sistem**, **Terang (Light)**, dan **Gelap (Dark)** yang langsung diterapkan ke seluruh elemen antarmuka, Forui components, dan modal sheet.
- **Informasi Build & Lisensi Terbuka**:
  - Penjelasan transparansi GPS, lisensi OSM, dan sifat estimasi harga.
- **Reset Data Contoh**:
  - Kemampuan mengembalikan data dummy (Trip Bandung + riwayat transaksi awal) melalui dialog konfirmasi aman.

---

## 4. Keamanan & Perilaku Sistem (Behavioral Contracts)

1. **Gerbang GPS Wajib (GPS Gatekeeper)**:
   - Aplikasi tidak dapat diakses tanpa layanan lokasi aktif dan izin GPS diberikan. Layanan memandu pengguna langsung ke pengaturan sistem perangkat jika GPS mati atau izin ditolak.
2. **Kemandirian Dependensi Ramping**:
   - Hanya mengandalkan dependensi esensial: `flutter_svg`, `forui`, dan `geolocator`. Tanpa bloatware pihak ketiga.
3. **Penyimpanan Cepat In-Memory**:
   - State dikelola secara reaktif menggunakan `ChangeNotifier` (`Store`) dengan pembaruan instan ke UI.
