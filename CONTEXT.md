# CPI — Shared Session Context (container: `cpi`)

> File ini adalah sumber kebenaran lintas-agent (Antigravity CLI/IDE, Claude Code, Cursor).
> Supermemory `containerTag` wajib = `cpi`. Daemon lokal: `sm start` / `sm status` (port 6767).

## Apa itu CPI
App Flutter Android: Cash, Plan & Itinerary — keuangan, rencana + rundown manual,
budget vs realisasi, GPS realtime wajib, pencarian hotel/stasiun live dari peta.
Forui + Material 3 dengan token light/dark bersama, ikon SVG custom di
`assets/icons/`. Versi source pada pubspec: 3.0.0+4; backend hybrid Supabase
dengan Supabase Storage (R2 dibatalkan, lihat bawah).

## Backend live (hybrid, terverifikasi 2026-10-20)
- **Supabase** `ijqbladnbvjslletwxey` (Singapore): Auth email/password (Confirm email
  MATI), 8 tabel + 21 RLS policy + 4 fungsi + trigger `on_auth_user_created`
  (workspace "Pribadi" otomatis). Diverifikasi via `supabase db query --linked`.
- Skema: `supabase/migrations/001_workspaces.sql` (wajib) + `002_reps.sql`
  (perwakilan absen; bila CLI 403, paste di SQL Editor).
- **Storage** (foto absen): Supabase Storage bucket `absensi` (publik, RLS
  per-member). Skema `003_storage.sql`. R2 DICORET atas permintaan user —
  tanpa dart-define tambahan, tanpa dep `http`/`crypto`.
- Kredensial TIDAK di-commit: semua via `--dart-define` (lihat README).
  Jangan minta/menyimpan `service_role key`.

## Struktur (`lib/`)
- `main.dart` — `CpiApp` (init Auth async), `AuthGate`, `Shell` (attach cloud per
  workspace aktif, state fresh per user via ValueKey email), `GpsGatePage`, Settings.
- `auth.dart` — `BackendConfig` (dart-define), `AuthService` (GoTrue stream).
- `login_page.dart` — Login/Signup + `ConfigMissingPage` + logout di AppBar.
- `workspace.dart` — `WsRole`, `Permissions.can` (matrix terpusat, dites),
  `WorkspaceService` (load/create/join-by-code/invite/members/roles).
- `workspace_page.dart` — ganti workspace, anggota, kode invite, buat/gabung.
- `sync.dart` — `CloudSync`: pull (remote menang), insert (id uuid server),
  toggle, hapus, complete. Gagal tulis = lokal dibatalkan + pesan.
- `core.dart` — model + `Store` async (`Future<String?>`, null = sukses).
  `removePlan` MELEPAS transaksi (tidak menghapus) — konsisten cloud (FK set null).
  `Rundown.day` (null = ikut tanggal plan).
- `attendance.dart` — `R2Config`/`R2Service` (SigV4 PUT), `Checkpoint`,
  `AttendanceRules` (headcount == jumlah anggota; submit hanya perwakilan,
  atau admin bila belum ditunjuk), `AttendanceService` + 4 titik default
  (titik kumpul opsional), `PhotoStore.upload` (uploadBinary + getPublicUrl).
- `absen.dart` — `CheckpointSection` (timeline + tunjuk perwakilan utk admin) +
  `AbsenSheet` (kamera, GPS, stepper headcount).
- `calendar.dart` — `groupByDay` (murni, dites) + `PlanCalendar`
  (TableCalendar + agenda hari + status "Berlangsung" via `activeRundown`).
- `pages.dart` — Home/Finance/Plans (+kalender di atas daftar)/Detail (+seksi absen)/Travel.
- `test/` — budget, ui, workspace (matrix+invite), sync (konversi+detach), attendance, calendar.

## Kontrak perilaku (jangan dilanggar tanpa diskusi)
1. GPS gate blokir; arrival <= 150m; 3 pemicu auto-selesai.
2. Riwayat uang TIDAK PERNAH ikut terhapus (detach). Berlaku lokal + cloud.
3. Harga travel = estimasi live berlabel; nama tempat asli OSM.
4. Tulis cloud gagal = batal + pesan (bukan data setengah). Pull = remote menang.
5. Absen: 1 foto + GPS + headcount == anggota; submit hanya perwakilan (atau
   admin bila perwakilan belum ditunjuk).
6. Deps auth/data/foto: `supabase_flutter`, `table_calendar`, `image_picker`.
  Jangan tambah dep untuk beberapa baris.

## Konvensi untuk agen AI
- Baca file yang disentuh + caller-nya sebelum edit (aturan ponytail).
- Keputusan arsitektur / bugfix non-trivial → `sm add "<1-3 kalimat>"` container `cpi`.
- MCP: entri `supabase` + `cloudflare` terdaftar di settings; OAuth Supabase
  bermasalah (`Unrecognized client_id` / `redirect_uri not allowed`) — pakai
  Supabase CLI (`npx supabase login`, `db query --linked`) sebagai gantinya.
- Flutter: `C:\Users\Xvis\flutter\bin\flutter.bat` (tidak di PATH).

## Handoff studi Ollo dan branding (2026-10-21)
- Permintaan pengguna: pelajari UI/komponen Ollo untuk implementasi **nanti**;
  buat variasi nama dan tipe ikon untuk direview sebelum pengguna menentukan.
  Belum ada nama, ikon, atau perubahan tampilan baru yang disetujui.
- Dokumen utama: `outputs/ollo-review/REVIEW.md`. Board enam konsep:
  `outputs/ollo-review/brand-options.png`, dihasilkan imagegen dan disalin ke
  workspace. A Bekal/flat, B SakuRute/monoline, C Ramu/modular,
  D Temu/soft 3D, E Lintas/duotone, F Reka/paper fold.
- Saran desain: Ramu untuk lingkup workspace/anggota/absen; Bekal untuk
  uang+perjalanan. Ini saran, **bukan pilihan pengguna**. Nama dan gaya ikon
  boleh dikombinasikan. Board bukan paket adaptive launcher icon siap rilis.
- Referensi lokal: `C:/Users/Xvis/Downloads/Telegram Desktop/Ollo.zip` dan
  folder ekstraksinya `.../Ollo`. Package `com.ollo.ollo`, versi 1.7.7+276,
  minSdk24. ZIP adalah base APK, bukan source Flutter.
- Manifest memerlukan split ABI/density; install gagal
  `INSTALL_FAILED_MISSING_SPLIT`. Folder tambahan tidak memuat split APK atau
  libapp.so. Jangan menyatakan UI/interaksi Ollo 1.7.7 sudah diuji runtime.
- Analisis visual memakai tujuh screenshot dari situs resmi
  `https://www.ollowithyou.xyz/`, disimpan dengan nama `official-*` di folder
  review. Screenshot promosi tidak membuktikan layout persis versi ZIP.
- Pola yang terlihat: period selector, balance summary dengan income/expense,
  shortcut, budget progress card, quick actions, form nominal besar dengan
  jenis/kategori, preview dompet, donut dan savings goal card.
- REVIEW.md memetakan pola ke komponen Forui dan fitur aktual CPI. Filter
  periode/budget/quick action dapat diadaptasi; kategori, transfer antar-wallet,
  voice dan scan perlu fitur data tersendiri, jangan diasumsikan sudah tersedia.
- Pertahankan DESIGN.md, `assets/theme.css`, `lib/theme/tokens.dart`, radius6,
  palet biru light/dark, dan komponen CpiCard/CpiButton/CpiField yang ada hingga
  pengguna memilih arah baru. Jangan menjalankan `forui init --force`.
- Tahap berikutnya menunggu review pengguna atas nama/ikon. Bila butuh audit
  runtime Ollo, minta paket .apks/.xapk lengkap atau split pendamping yang cocok.
  Tidak ada source aplikasi atau aset launcher yang diubah pada studi ini.

## Eksplorasi branding sebelumnya (2026-10-21, lihat koreksi terbaru di bawah)
- Pengguna meminta **CPI** dengan variasi bahasa dan ikon; arah nama alternatif
  Bekal/Ramu/Temu tidak dilanjutkan sebagai pilihan utama.
- Board baru: `outputs/cpi-brand-review/cpi-icon-options.png` dengan enam gaya
  monogram CPI (A geometric, B route line, C modular, D soft 3D, E stencil,
  F folded). Penjelasan bahasa dan pilihan: `outputs/cpi-brand-review/REVIEW.md`.
- Usulan kepanjangan Italia: Conti, Piani, Itinerari; Indonesia: Catat, Pantau,
  Ikuti. Ini usulan kreatif, bukan pilihan kepanjangan yang sudah disetujui.
- Ikon A direkomendasikan dan dibuatkan PNG terpisah untuk review. Ikon belum
  diterapkan pada launcher; pengguna belum memilih gaya final. Bahasa UI dan
  token warna aplikasi tetap mengikuti konfigurasi yang ada.

## Koreksi branding terbaru: nama utuh + Folded (2026-10-21)
- Pengguna memperjelas: CPI adalah singkatan; yang diminta **nama merek baru
  yang mencakup seluruh fitur**, bukan kepanjangan CPI dalam bahasa lain.
  Eksplorasi kepanjangan/monogram CPI sebelumnya bukan arah final.
- Pengguna secara eksplisit memilih gaya ikon **Folded**.
- Usulan yang dibuat: **Rangkai**, menyatukan uang, rencana, perjalanan,
  workspace, anggota dan kegiatan. Nama ini masih usulan untuk review,
  bukan pilihan nama yang sudah dikonfirmasi pengguna.
- Ikon R folded-paper ivory/biru: `outputs/rangkai-brand-review/rangkai-folded.png`.
  Penjelasan: `outputs/rangkai-brand-review/REVIEW.md`. Ini PNG konsep dari
  imagegen; belum paket adaptive icon dan belum dipasang ke aplikasi.
- Source aplikasi, launcher, package ID dan token light/dark tidak berubah.
