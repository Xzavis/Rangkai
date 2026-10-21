# Paket UI v4 Rangkai

Handoff untuk Muse Agent Code, 21 Oktober 2026. Berisi **16 versi terpilih** dari Stitch setelah distill, clarify dan polish, dengan ekspor HTML/CSS lokal yang kemudian diperbaiki untuk responsivitas, navigasi dan aset offline. Ini target implementasi Flutter, bukan perubahan UI runtime yang sudah selesai.

- Mulai dari [MUSE_HANDOFF.md](../../MUSE_HANDOFF.md).
- Buka [galeri offline](reference/index.html), atau lihat PNG/HTML dari tabel di bawah. GitHub menampilkan source HTML; untuk interaksi unduh/checkout repo lalu buka galeri lokal.
- [DESIGN.md](../../DESIGN.md), [COMPONENTS.md](COMPONENTS.md), [SCREENS.md](SCREENS.md), [GAPS.md](GAPS.md), [IMPLEMENTATION.md](IMPLEMENTATION.md).
- [manifest.json](manifest.json): route, source symbol, ID Stitch, dimensi dan SHA-256 aset.
- [tokens.json](tokens.json), [fixtures.json](fixtures.json), [browser-qa.json](browser-qa.json).

## Indeks 16 layar

| ID | Layar | Referensi | Source saat ini |
|---|---|---|---|
| 01 | Beranda | [PNG](reference/01-Beranda.png) · [HTML](reference/01-Beranda.html) | `lib/pages.dart` · `HomePage` |
| 02 | Keuangan | [PNG](reference/02-Keuangan.png) · [HTML](reference/02-Keuangan.html) | `lib/pages.dart` · `FinancePage` |
| 03 | Rencana | [PNG](reference/03-Rencana.png) · [HTML](reference/03-Rencana.html) | `lib/pages.dart` · `PlansPage` |
| 04 | Detail rencana | [PNG](reference/04-Detail-Rencana.png) · [HTML](reference/04-Detail-Rencana.html) | `lib/pages.dart` · `PlanDetailPage` |
| 05 | Tambah transaksi | [PNG](reference/05-Tambah-Transaksi.png) · [HTML](reference/05-Tambah-Transaksi.html) | `lib/pages.dart` · `showTxSheet` |
| 06 | Cari kereta | [PNG](reference/06-Cari-Kereta.png) · [HTML](reference/06-Cari-Kereta.html) | `lib/pages.dart` · `TravelPage` |
| 07 | Cari hotel | [PNG](reference/07-Cari-Hotel.png) · [HTML](reference/07-Cari-Hotel.html) | `lib/pages.dart` · `TravelPage` |
| 08 | Kalender | [PNG](reference/08-Kalender.png) · [HTML](reference/08-Kalender.html) | `lib/calendar.dart` · `PlanCalendar` |
| 09 | Workspace | [PNG](reference/09-Workspace-Komunitas.png) · [HTML](reference/09-Workspace-Komunitas.html) | `lib/workspace_page.dart` · `WorkspacePage` |
| 10 | Absen tim | [PNG](reference/10-Absen-Tim.png) · [HTML](reference/10-Absen-Tim.html) | `lib/absen.dart` · `AbsenSheet` |
| 11 | Masuk | [PNG](reference/11-Masuk.png) · [HTML](reference/11-Masuk.html) | `lib/login_page.dart` · `LoginPage` |
| 12 | Daftar | [PNG](reference/12-Daftar.png) · [HTML](reference/12-Daftar.html) | `lib/login_page.dart` · `LoginPage` |
| 13 | Aktifkan lokasi | [PNG](reference/13-Aktifkan-Lokasi.png) · [HTML](reference/13-Aktifkan-Lokasi.html) | `lib/main.dart` · `GpsGatePage` |
| 14 | Buat rencana | [PNG](reference/14-Buat-Rencana.png) · [HTML](reference/14-Buat-Rencana.html) | `lib/pages.dart` · `showPlanSheet` |
| 15 | Budget & Split | [PNG](reference/15-Budget-Split.png) · [HTML](reference/15-Budget-Split.html) | `lib/core.dart` · `BudgetCalc` |
| 16 | Pengaturan | [PNG](reference/16-Pengaturan.png) · [HTML](reference/16-Pengaturan.html) | `lib/main.dart` · `SettingsPage` |

## Asal dan prioritas referensi

[Proyek Stitch](https://stitch.withgoogle.com/projects/12569152226259471213) dapat memuat draf duplikat. Manifest memilih satu versi per layar. **PNG/HTML lokal dalam paket ini adalah acuan visual final**, karena ada polish tambahan sesudah ekspor Stitch. Jangan memilih layar lain hanya karena tampak paling baru pada kanvas.

HTML menyertakan Tailwind yang sudah dikompilasi, CSS bersama, Inter, Source Serif 4 dan Material Symbols lokal. Tidak perlu CDN atau Node untuk membuka pratinjau. Navigasi, visibilitas saldo dan kata sandi tersedia untuk review; backend, kamera dan GPS tidak berjalan dalam HTML. Terjemahkan komponen ke Flutter, bukan menanam HTML di WebView.

## Bukti yang tersedia

Browser QA sebelumnya meliputi 16 layar pada 360×800, 390×844, 430×932 dan teks 200% pada lebar 390, tanpa error JavaScript atau elemen terukur keluar horizontal. Tombol saldo/kata sandi dan fokus keyboard diuji. Ini bukti ekspor HTML saja, **bukan hasil tes Flutter atau sertifikasi aksesibilitas**. Detektor Impeccable dijalankan satu kali dan menghasilkan 95 peringatan awal, lalu diikuti koreksi manual; tidak ada klaim pemindaian ulang bersih.

Validasi kelengkapan paket dan fixture:

```sh
python3 tools/validate_ui_handoff.py
```

Jalankan dari root repo. Untuk perbedaan data ilustrasi, kemampuan source yang belum ada, dan prasyarat build lihat GAPS.md. Paket tidak menyertakan APK, kredensial, atau perubahan backend live.
