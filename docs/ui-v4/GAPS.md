# Selisih UI baru terhadap source

Audit source dasar: `a1598a0bd40abb4d00a372cf5edcb516fe4b41c1`, branch main, 21 Oktober 2026. Nama file dan simbol di bawah sudah diperiksa. Kolom "target" adalah pekerjaan implementasi berikutnya; handoff ini belum melakukannya.

| Area | Source yang ada | Target dan keputusan implementasi |
|---|---|---|
| Navigasi | Shell memiliki 4 tab; Travel tab; Workspace lewat app bar; PlanCalendar tertanam di PlansPage. | Lima tab Beranda/Keuangan/Rencana/Kalender/Workspace. Travel menjadi route dalam Rencana. Hindari kalender dan app bar ganda; pertahankan state lintas tab dan rail. |
| Kategori/catatan transaksi | Tx hanya id/title/amount/date/planId. Store.addTx membentuk ulang objek; CloudSync.txRow/txFrom tidak punya kategori/note. | Tambah field backward compatible, default kategori umum, note opsional; teruskan melalui copy Store, converter dan migrasi baru. Jangan menyimpan hanya di widget atau mengabaikan field setelah submit. |
| Tanggal transaksi | Tx.date ada, tetapi showTxSheet selalu memakai DateTime.now(). | Picker harus mengisi Tx.date yang dipilih dan round-trip; grouping/filter memakai tanggal transaksi, bukan urutan insert atau created_at. |
| Periode/type transaksi | FinancePage hanya mencari judul. | Picker bulan dan filter semua/pemasukan/pengeluaran bekerja terhadap date dan tanda amount; label bulan mengikuti pilihan. |
| Rentang rencana | Plan.date tunggal; Rundown.day sudah tersedia. | Tambah endDate nullable dengan fallback date untuk data lama; validasi akhir>=awal; teruskan di Store.addPlan, converter, migration dan editor. Rundown hari kedua masuk kalender. |
| Tambah dari travel | TravelPage(travel) hanya menampilkan Offer; Offer tidak menyimpan identitas/koordinat tempat; belum menerima store/plan. | Teruskan store/konteks plan; pilih plan dan jam/hari, buat Rundown dengan biaya estimasi. Bila dipakai memilih tujuan, simpan koordinat hasil OSM yang nyata. Jangan buat transaksi paid atau koordinat fiktif. |
| Budget & Split | BudgetCalc sudah punya spent/sisa/ratio; belum ada halaman split. | Halaman baru, jumlah orang>=1, kalkulasi lokal dan Clipboard. Tidak perlu tabel pembayaran baru. Tentukan pembulatan rupiah: tampilkan quotient dan sisa pembagian secara jelas bila tidak habis dibagi. |
| Izin/offline login | CpiApp memiliki onOffline melalui AuthGate; BackendGagalPage sudah memakainya. LoginPage dan ConfigMissingPage belum menyediakan callback tersebut. | Wire aksi Lanjut offline pada entry yang tepat ke root, tanpa bypass GpsGatePage. Pertahankan retry saat init gagal dan signOut/isolasi state per user. |
| Workspace offline | WorkspacePage membutuhkan service non-null. | Tab tetap ada dengan empty/offline state, tombol Masuk, dan aksi cloud tidak aktif. Jangan menampilkan empat anggota dummy di workspace nyata. |
| Perwakilan absen | plan_reps dan AttendanceService.setRep/getRep memakai planId. | Kartu workspace memilih/menampilkan rencana aktif beserta checkpoint. Bima pada mockup adalah contoh perwakilan plan Trip Bandung, bukan perwakilan global workspace. |
| Radius checkpoint absen | Checkpoint hanya id/planId/name/required/record. AbsenSheet memeriksa foto, GPS dan headcount; tidak menghitung radius checkpoint. | Badge "Dalam radius 150m" dan jarak42m belum didukung. Butuh koordinat/radius checkpoint, editor, konversi/schema, perhitungan jarak serta validasi submit yang nyata. Titik lama tanpa koordinat: tampilkan "Titik belum diatur", bukan status valid. Radius ini terpisah dari arrival rencana yang sudah ada. |
| Profil/kode undangan | Membership berisi userId/role/email. WorkspaceService.newCode menghasilkan 6 karakter. | Gunakan nama profil yang benar-benar tersedia atau email/initial; Rian dkk hanya fixture. RANGKAI24 pada gambar contoh bukan alasan mengganti format generator atau hardcode kode. |
| Reset | Store.reset: lokal clear+seed; cloud clear lalu pull(), tanpa menghapus server atau memasukkan seed. | Copy destruktif reset hanya untuk lokal. Pada cloud beri aksi "Muat ulang workspace" dengan copy yang sesuai, atau spesifikasikan fitur reset cloud terpisah. Jangan mengubahnya menjadi penghapusan server demi meniru screenshot. |
| Jam/zona dan fitur lama | Beranda punya jam multi-zona; source punya delete transaksi, semua-rundown-selesai, estimasi travel8detik. | Pertahankan kemampuan tersebut, boleh pindahkan jam/zona ke detail waktu yang ringkas. Hilangnya elemen pada PNG tidak menghapus kontrak fitur. |
| Tema | Light/dark/system sudah ada; dokumen lama radius6/warna lama. | Token dan geometri light baru mengikuti DESIGN.md; dark tetap didukung dan perlu pemeriksaan tersendiri. Tidak ada PNG dark baru yang sudah disetujui. |

## Prasyarat repo yang terlihat pada commit dasar

- Tree GitHub tidak memuat folder `assets/`, walaupun pubspec merujuk assets/icons, assets/theme.css dan tiga font. Teks pada README/test yang menyebut aset itu bukan bukti berkas tersedia. Reference/assets berisi font untuk pratinjau; pulihkan/paketkan aset runtime dan notice yang sesuai pada implementasi.
- `lib/theme/theme.dart` mengimpor `package:material_ui/material_ui.dart`, sedangkan pubspec tidak mendeklarasikannya secara langsung. Verifikasi hasil resolver dan integrasi tema sebelum mengklaim analyzer/build lulus.
- Tree Android hanya memuat manifest dan ikon launcher; wrapper/skrip Gradle dan scaffold platform lengkap tidak tampak. Jangan menyatakan APK dapat dibangun dari checkout ini tanpa melengkapi prasyarat.
- Tidak ada hasil Flutter analyzer/test/build baru dalam handoff ini. Dokumen lama menyebut versi3.0.0+4, tetapi pubspec dasar sudah 4.0.0+1. Jangan mengganti version/name/package ID untuk sekadar menyelaraskan judul dokumen.

Pulihkan file platform/aset dengan menjaga manifest, izin GPS/kamera, branding launcher dan konfigurasi backend. Jangan menimpa source secara massal dengan generator proyek.

## Data ilustrasi yang perlu direkonsiliasi

Ledger fixture konsisten: income6.000.000, expense1.750.000, balance4.250.000. Tiga transaksi Trip Bandung adalah makan150.000, kereta250.000, uang muka hotel350.000 =750.000. Kopi45.000 tidak tertaut ke plan tersebut.

PNG Beranda menampilkan transaksi contoh terkurasi, bukan selalu tiga terbaru dari ledger lengkap. Saat implementasi, urutkan date aktual; dengan fixture ini kopi menggantikan gaji sebagai item ketiga. Kartu acara komunitas pada PNG Rencana menyebut sisa1.700.000 tanpa ledger pendukung; fixture memberi budget2.000.000 dan spent0 sehingga sisa2.000.000. Jangan menciptakan pengeluaran tersembunyi agar cocok dengan angka ilustrasi.

Waktu09:41 pada status bar dan posisi GPS pada layar pencarian kereta adalah skenario ilustrasi berbeda dari tracking Bandung. Jangan menggambar status bar tiruan atau memaksa kedua lokasi sebagai satu posisi perangkat. Rian, Nadia, Bima, Sari, kode undangan dan foto siap pada mockup adalah data contoh, bukan data akun atau bukti absensi yang sudah tersimpan.
