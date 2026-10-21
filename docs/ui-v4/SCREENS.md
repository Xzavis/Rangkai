# Spesifikasi 16 layar

ID mengacu pada manifest.json dan PNG/HTML dengan awalan yang sama. Struktur visual mengikuti ekspor lokal; state dan perilaku mengikuti layanan nyata. Semua layar harus mempunyai state loading/empty/error yang relevan. Nama route pada manifest adalah kontrak target untuk implementasi, bukan route Flutter yang sudah didaftarkan.

## 01 — Beranda · home

Urutan: header merek/workspace dan Pengaturan; sapaan dan tanggal; saldo dengan visibilitas; pemasukan/pengeluaran; Tambah transaksi dan Buat rencana; ringkasan plan aktif dengan GPS, anggaran dan agenda berikutnya; transaksi terakhir; lima tab.

- Saldo/pemasukan/pengeluaran dihitung dari Store workspace aktif. Visibilitas saldo state lokal, tidak mengubah nilai atau clipboard.
- Tambah transaksi→05; Buat rencana→14; Lihat rencana→04 dengan planId; Lihat semua transaksi→02; Pengaturan→16.
- Nama sapaan berasal dari data yang tersedia; offline memakai sapaan umum. Jam/zona yang sudah didukung tetap tersedia melalui detail waktu ringkas, bukan dihapus.
- Tanpa plan atau transaksi tampilkan empty state dengan CTA yang sesuai. Baris transaksi diurut date aktual, bukan urutan showcase pada PNG.

## 02 — Keuangan · finance

Urutan: judul/pemilih bulan/salin; saldo dan arus kas; tombol utama Tambah transaksi dalam alur konten; Budget & Split dan Salin ringkasan; pencarian; filter Semua/Pemasukan/Pengeluaran; daftar dikelompokkan hari.

- Bulan/type/search memfilter daftar dan subtotal per hari. Kartu `Saldo saat ini` tetap memakai total workspace aktif dari Store; jelaskan pemilih bulan sebagai filter daftar, jangan menyamarkannya sebagai saldo bulanan.
- Tambah transaksi→05; Budget & Split→15 dengan pemilih plan; salin memakai Clipboard dan data aktual. Pertahankan aksi hapus transaksi dan tampilkan error cloud bila gagal.
- Nominal utuh, judul boleh membungkus; CTA tidak melayang di atas baris terakhir. Tidak ada hitungan record hardcode pada tab filter.
- Pencarian kosong, tak ada transaksi pada bulan pilihan, dan error mutasi dibedakan. Kopi pada fixture tidak terkait Trip Bandung.

## 03 — Rencana · plans

Filter Semua/Berlangsung/Mendatang; kartu plan aktif dan mendatang dengan tanggal, tujuan, tracking, anggaran, rundown selesai dan agenda berikutnya; akses Cari kereta/Cari hotel.

- Buat rencana→14; kartu/detail→04; Cari kereta→06 dan Cari hotel→07. Bawa planId bila berasal dari konteks plan tertentu.
- Jumlah/status dihitung dari data/date/tracking. Tidak menambah tab arsip selesai: plan yang selesai memang dihapus, transaksinya dilepas.
- Progress mengacu pengeluaran aktual, bukan total estimasi rundown. Sisa dapat negatif. Filter tidak menghapus state daftar.
- Tanpa plan tampilkan Buat rencana dan akses travel yang masih bermakna.

## 04 — Detail rencana · plan-detail

Header judul/tanggal/status; ringkasan anggaran; tracking ke tujuan; timeline rundown; transaksi terkait; aksi Selesaikan dan hapus dengan penjelasan transaksi tetap tersimpan.

- Semua bagian membaca planId yang sama. Tracking mula-mula mengikuti state riil; sebelum aktif tampilkan `Mulai tracking`, bukan selalu `Jeda tracking` seperti skenario PNG.
- <=150 m hanya menjadi pemicu arrival saat tracking aktif. Semua rundown selesai dan aksi manual juga memanggil jalur complete-and-detach. Jika plan terhapus saat layar terbuka, keluar ke daftar secara aman.
- Tambah/hapus/toggle rundown tetap memakai Store dan role yang sesuai; semua error ditampilkan. Menambah biaya estimasi tidak menciptakan transaksi uang.
- Pengeluaran terkait pada fixture tepat tiga: makan150.000, kereta250.000 dan uang muka hotel350.000. Jangan menduplikasi uang muka.
- Lokasi belum siap, tujuan tanpa koordinat, belum mulai, tracking aktif/jeda dan penyelesaian gagal memiliki state berbeda. Tombol manual memakai konfirmasi.

## 05 — Tambah transaksi · transaction-create

Layar/form yang dapat digulir: jenis; Jumlah (Rp); nama; tanggal; kategori yang membungkus; plan opsional; catatan opsional; Simpan transaksi/Batal.

- Pertahankan entry `showTxSheet` bila berguna, tetapi gunakan layout penuh/scrollable sesuai referensi, bukan panel dangkal yang menyembunyikan field.
- Nominal>0; tanda dari jenis; nama wajib; date berasal dari picker. Kategori dan catatan memerlukan model+sync+schema pada GAPS.md.
- Pemasukan tidak tertaut plan. Pengeluaran boleh memilih Tanpa rencana. Mengganti jenis membersihkan planId yang tidak lagi berlaku.
- Busy mencegah submit ganda; gagal mempertahankan isian; sukses memanggil Store.addTx lalu kembali dan memperbarui daftar/anggaran. Tidak menutup form setelah error.

## 06 — Cari kereta · travel-train

Header/back; pilihan Kereta/Hotel; informasi posisi bila tersedia; asal/tujuan dan aksi tukar; tanggal/penumpang; rute pilihan; estimasi biaya dan unit; alternatif; penjelasan OSM dan estimasi.

- Pencarian mengonsumsi hasil OSM, menampilkan loading/no results/error/retry. Tukar mengubah state pencarian nyata. Jangan menampilkan nama kereta, jam resmi, kursi atau kode pemesanan yang tidak diberikan API.
- `Tambahkan ke rencana` memilih plan/hari/jam lalu menyimpan rundown estimasi melalui Store; hasil hanya sukses setelah tersimpan. Tanpa plan tawarkan buat/pilih plan.
- Field asal/tujuan/tanggal/jumlah orang tidak boleh dekoratif. Lengkapi state/koneksi service pada GAPS.md sebelum menampilkan kontrol sebagai aktif.
- Tab Hotel→07 dengan konteks perjalanan yang masuk akal; kembali ke Rencana. Estimasi tetap bukan harga tiket resmi atau pembayaran.

## 07 — Cari hotel · travel-hotel

Header konteks destinasi; pilihan Kereta/Hotel; kota dan tanggal malam; hasil pilihan serta alternatif dengan alamat, estimasi/malam dan CTA; catatan OSM.

- Hasil, jarak dan koordinat berasal dari pencarian/posisi nyata. Biaya total bila dipakai harus memperhitungkan jumlah malam; jangan menganggap tarif/malam sebagai total tanpa label.
- Add-to-plan sama dengan06; memilih tujuan plan menyimpan koordinat hasil OSM, bukan teks nama saja. Tidak ada checkout/booking palsu.
- Empty/error/location unavailable tetap bisa dipahami. Tidak perlu foto hotel eksternal untuk mereplikasi layout.

## 08 — Kalender · calendar

Halaman mandiri: judul/Buat rencana; bulan dan kontrol prev/next; minggu mulai Senin; tanggal bertanda; tanggal pilihan; agenda berurutan jam; rencana mendatang.

- Gunakan `groupByDay` dan `Rundown.day ?? Plan.date`; jangan menulis ulang sumber agenda di widget. Kalender tidak ditampilkan lagi di atas daftar PlansPage.
- Pilih hari memperbarui agenda; prev/next memperbarui bulan; tap agenda→04; Buat rencana→14. Pertahankan selected/focused saat pindah tab.
- Lokal Indonesia dan urutan Senin–Minggu. Pada Oktober2026, tanggal1 Kamis;24 dan31 Sabtu. Hari tanpa agenda menampilkan empty state.
- Data multi-hari berasal dari tanggal yang tersimpan, bukan string rentang pada gambar.

## 09 — Workspace · workspace

Header/mode Pribadi-Komunitas; workspace aktif dan kode undangan; buat/gabung; konteks checkpoint rencana; Buka absen; perwakilan; daftar anggota dan peran.

- Semua data dari WorkspaceService. Gunakan format kode service, bukan RANGKAI24 hardcode; Salin dan Buat kode baru mempunyai hasil nyata.
- Mutasi role/checkpoint/perwakilan mengikuti Permissions dan hasil service. Anggota biasa tetap dapat membaca hal yang memang diizinkan, tanpa kontrol admin aktif palsu.
- Checkpoint dan perwakilan terikat **planId**; tampilkan plan yang dipilih pada kartu sebelum membuka10. Geofence dan nama profil yang belum tersedia tercantum pada GAPS.md.
- Offline/service null→state penjelasan + Masuk, tidak crash, tidak menampilkan anggota/kode fiktif sebagai tersambung. Loading, list kosong, invite invalid dan operasi gagal mempunyai feedback.

## 10 — Absen tim · attendance

Konteks plan/checkpoint dan perwakilan; lokasi/radius bila didukung; foto grup atau preview; Foto ulang; headcount manual; ringkasan syarat; Kirim absen.

- Ambil foto melalui ImagePicker. Badge `Foto grup siap` hanya setelah ada file; `4 orang` adalah input manual, bukan hasil AI.
- Member count dari workspace saat ini; headcount harus sama dan>=1. Izin submit memakai AttendanceRules.canSubmit: perwakilan jika sudah ditunjuk, admin/owner jika belum.
- GPS harus punya posisi. Radius150m pada checkpoint dan jarak42m ilustrasi belum ada di source; lengkapi koordinat/geofence dahulu, atau tampilkan `Titik belum diatur` tanpa valid badge.
- Kirim→upload+record melalui service. Busy, upload gagal, foto terupload tetapi record gagal, dan sukses dibedakan. Jangan menyatakan bukti tersimpan sebelum service sukses.

## 11 — Masuk · login

Brand/sapaan; email; kata sandi dengan visibilitas; Masuk; link Daftar; Lanjut offline dan keterangan data lokal.

- Field produksi tidak diisi password contoh pada HTML. Pakai autofill yang tepat dan semantics tombol show/hide.
- Masuk memakai AuthService.signIn; busy/error terlihat; state user baru tidak memakai workspace akun sebelumnya. Daftar→12.
- Lanjut offline perlu callback root sebagaimana GAPS.md; tetap melewati GPS gate. Pertahankan BackendGagalPage/ConfigMissingPage/retry sehingga init gagal tidak menjadi splash buntu.

## 12 — Daftar · signup

Form email/password, helper minimal6 karakter, Daftar dan link Masuk.

- Boleh memakai LoginPage yang sama dengan mode berbeda. Validasi email dan password>=6; show/hide, loading dan error backend bekerja.
- Sukses mengikuti hasil AuthService/session, bukan langsung menampilkan workspace dummy. Tidak mengarang janji enkripsi atau setup backend dari mockup.

## 13 — Aktifkan lokasi · location-gate

Penjelasan untuk tracking dan bukti absen; langkah izin, layanan GPS dan pembacaan posisi; Izinkan lokasi/Buka pengaturan; instruksi bila izin permanen ditolak.

- GpsGatePage mengamati LocationService. Bedakan denied, deniedForever, service off, menunggu posisi dan ready. Tombol memanggil aksi yang sesuai, bukan sekadar mengubah badge.
- Tidak ada Lewati yang membuka shell tanpa lokasi; offline mode tetap mengikuti aturan GPS. Saat resumed periksa ulang layanan/izin.
- CTA masih dapat dicapai saat teks besar dan tidak didorong oleh ilustrasi radar besar.

## 14 — Buat rencana · plan-create

Nama; anggaran; rentang tanggal; pencarian/pilihan destinasi; status koordinat tersimpan; rundown awal opsional; penjelasan radius; Simpan/Batal.

- Nama dan budget valid; end>=start; destinasi harus dari satu hasil OSM dengan lat/lng. `Tersimpan` di blok tujuan berarti pilihan lokasi tersedia, bukan plan sudah berhasil dibuat.
- Bila teks destinasi diedit ulang, batalkan pilihan koordinat lama. Jangan menaruh koordinat contoh di model produksi.
- Rundown awal bila diisi harus benar-benar ikut disimpan. Store.addPlan saat ini membentuk ulang Plan tanpa menyalin rundown; implementasikan urutan penyimpanan/penanganan kegagalannya secara eksplisit. Jangan menutup form ketika sebagian gagal.
- Tidak menambahkan template itinerary wajib atau wizard semu. Date range dan metadata baru mengikuti GAPS.md.

## 15 — Budget & Split · budget-split

Pemilih plan; total anggaran, progress linear, terpakai/sisa; total biaya patungan; jumlah orang; hasil/orang dan Salin hasil.

- Budget dibaca dari plan, terpakai dari BudgetCalc.spentOf, sisa=budget-spent. Bukan ring dan bar ganda untuk metrik sama.
- Nilai biaya awal dapat memakai spent plan. Mengedit biaya split tidak mengubah transaksi atau anggaran. Jumlah orang>=1, hasil tidak NaN/Infinity; pembagian yang tidak habis menampilkan sisa rupiah secara jelas.
- Fixture750.000÷4=187.500, sisa0. Salin hasil memuat total/orang/hasil dan feedback. Tidak ada pembayaran atau transfer.

## 16 — Pengaturan · settings

Profil/status; tema Terang/Gelap/Sistem; workspace aktif dan ganti; salin ringkasan; aksi data; logout; versi dari package.

- Tema mengubah semua route/modal; profil/versi/status berasal dari state, bukan teks contoh.
- Ganti workspace→09; Salin memakai data aktif. Logout hanya jika login, mengikuti konfirmasi/source dan membuang state akun sesuai flow root.
- Reset lokal: jelaskan transaksi/rencana diganti data contoh dan minta konfirmasi. **Cloud:** implementasi sekarang reload; tampilkan `Muat ulang workspace` dan copy yang sesuai, tanpa penghapusan server.
- Jangan hardcode badge tersambung hanya karena backend URL dikonfigurasi. Data lokal in-memory tidak boleh dijanjikan persisten lintas restart.
