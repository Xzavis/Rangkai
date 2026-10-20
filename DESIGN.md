# CPI versi 3

## Arah desain
Arahan pengguna: Forui dengan palet light/dark yang diberikan. Saldo, budget dan
rundown perjalanan menjadi fokus. ENERGY 1 / RHYTHM 2 / MOTION 1.

## Sistem visual
Token lintas platform ada di `assets/theme.css`, padanan Flutter ada di
`lib/theme/tokens.dart`. Warna dipakai persis, tanpa pembentukan palet dari seed.
Radius dasar 0.375rem = 6 logical pixels untuk card, field, dan tombol; sheet 12.
Permukaan netral datar dan border tipis. Biru menandai aksi utama dan fokus.
Inter untuk UI dan nominal, JetBrains Mono untuk jam/koordinat, Source Serif 4
sebagai token serif. Font dibundel untuk penggunaan offline. Ikon SVG CPI
dipertahankan karena mewakili uang, kalender, dan perjalanan.

## Komponen dan perilaku
Forui menyediakan card, tombol, input pencarian/transaksi dan pilihan mode.
Material menyediakan navigasi, picker dan modal dengan warna yang sama.
Mode Sistem/Terang/Gelap berlaku ke semua route dan modal. Palet seed lama
diganti palet pengguna. GPS gate, riwayat transaksi dan tracking tetap berlaku.
Titik live statis; gerakan hanya untuk perubahan data/navigasi dan menghormati
preferensi pengurangan gerak. Harga travel selalu diberi label estimasi.

## Layout
- <600: satu kolom, padding 16, empat tujuan navigasi bawah.
- 600–959: padding 24, konten maksimal 880; rail ringkas mulai lebar 720.
- >=960: rail berlabel, konten maksimal 1120.
- Ring budget dan ringkasan menumpuk saat ruang sempit. Form dapat digulir
  dengan keyboard terbuka; daftar menyediakan ruang untuk tombol tambah.
- Target sentuh minimal 44×44, fokus terlihat, teks dapat membungkus.

## Kontras
Putih di atas primary #3b82f6 sekitar 3.68:1 dan destructive #ef4444 sekitar
3.76:1. Token pengguna dipertahankan; label aksi pada pasangan ini memakai 19px
tebal agar memenuhi ambang 3:1 untuk teks besar. Error teks kecil memakai tinta
turunan #b91c1c (light) / #fca5a5 (dark). Border dekoratif memakai token asli.

## Verifikasi
Uji light/dark pada lebar 320, 390, 768, 1280 dan skala teks besar, mode tema,
form transaksi, analyzer, test dan build APK. Hasil: `outputs/ui-verification.md`.
