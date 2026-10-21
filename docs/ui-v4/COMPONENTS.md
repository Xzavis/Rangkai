# Komponen dan pemetaan Flutter

Pertahankan Forui + Material dan lapisan layanan yang ada. Nama target di bawah adalah usulan komponen yang boleh digabung sesuai kebutuhan; bukan kelas yang sudah tersedia.

| Target UI | Titik mulai | Kontrak |
|---|---|---|
| RangkaiScaffold / app bar | Shell, CpiContent | SafeArea, lima tab, rail adaptif, judul satu kali, workspace/settings sesuai konteks. Tidak membuat Scaffold/AppBar ganda saat WorkspacePage menjadi tab. |
| RangkaiCard | CpiCard + FCardStyle | Radius 16, border tipis, tanpa shadow; padding isi 20 hanya satu lapis. |
| Primary/secondary/destructive action | CpiButton | Radius 12; minimum sentuh 44, tombol utama 48; ikon dan label tidak terpotong; state busy/disabled/focus. Font target 14–15 sesuai konteks, bukan 19px yang dipaksakan v3. |
| Labeled field | CpiField / FTextField | Label permanen, tinggi minimum 48, helper/error, keyboard dan aksi next/done yang benar. Password visibility memiliki semantics/tooltip. |
| BalanceSummary | HomePage, FinancePage, _Mini | Saldo serta pemasukan/pengeluaran dari Store; income/expense bukan warna saja; show/hide saldo state lokal. |
| TransactionRow | TxTile | Judul, tanggal, kategori bila model mendukung, plan label opsional, nominal utuh. Hapus tetap tersedia melalui aksi yang dapat ditemukan, dengan error jika cloud gagal. |
| PlanSummary / BudgetProgress | _PlanList, BudgetCalc, BudgetRing | Progress linear, terpakai/sisa dari ledger. Hindari ring dan bar berulang untuk rasio yang sama. Sisa negatif tidak dipaksa nol; budget0 tidak menyebabkan pembagian nol. |
| RundownTimeline / AgendaRow | PlanDetailPage, PlanCalendar | Urut tanggal lalu jam, state belum/sedang/selesai, estimasi biaya berbeda dari pengeluaran aktual. |
| StatusLabel | LiveDot + Text | Statis, teks menjelaskan aktif/menunggu/gagal; tidak hardcode GPS siap atau sinkron berhasil. |
| CategorySelector | Baru, form transaksi | Wrap/grid sesuai ruang, satu pilihan aktif, semantics; nilai stabil tersimpan round-trip setelah gap model diselesaikan. |
| TravelResult | TravelPage + Offer | OSM name, estimasi dan unit biaya; add-to-plan butuh plan dan jadwal nyata, bukan checkout. |
| WorkspaceHeader / MemberRow | WorkspacePage + WorkspaceService | Role dan invite code dari service. Nama contoh bukan field displayName yang sudah tersedia; fallback email/initial yang jujur. |
| Checkpoint / AttendancePhoto / Headcount | CheckpointSection, AbsenSheet | Konteks plan+checkpoint, role perwakilan, foto nyata, jumlah manual, GPS nyata. Radius badge hanya bila geofence benar-benar didukung. |
| EqualSplit | Halaman baru memakai BudgetCalc | Total integer rupiah, orang>=1, hasil dan sisa pembulatan jelas, salin hasil; bukan transfer/pembayaran. |

## Komponen harus mengakomodasi

- Light/dark/system; pending, success, error, empty dan offline bila relevan.
- TextScaler 2.0; nama panjang; nilai uang besar/negatif; label navigasi membungkus.
- Fokus/semantics, target sentuh, reduced motion dan keyboard inset.
- Tekan ganda saat busy tidak membuat transaksi atau absen ganda.

## Batas aset

Ikon pada HTML adalah Material Symbols Outlined. Pilih padanan outline yang konsisten dalam Flutter dan pertahankan simbol domain (uang, rencana, kalender, workspace). Jangan mengganti launcher folded karena simbol rantai pada header. Font/ikon di reference/assets hanya mendukung pratinjau; pastikan font produksi dan lisensinya benar-benar dibundel sebelum menyatakan aplikasi bekerja offline.
