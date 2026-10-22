# vision_windows — E2E visual Android lewat USB di Windows

Tool ini mengirim screenshot PNG asli langsung ke model vision, kemudian
menjalankan satu aksi ADB berdasarkan gambar tersebut. Tidak ada snapshot
accessibility, UIAutomator dump, XML, OCR, atau selector widget. Screenshot
menggunakan `adb exec-out screencap -p` dalam mode biner sehingga tidak rusak
oleh redirection PowerShell. Lihat [dokumentasi ADB](https://developer.android.com/tools/adb#screencap).

## Persiapan

1. Python 3.10+ untuk CLI; Python 3.11+ dan SDK MCP untuk server.
2. Android platform-tools di PATH, `ANDROID_HOME`/`ANDROID_SDK_ROOT`, atau
   `%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe`. Opsi `--adb` menerima path eksplisit.
3. Aktifkan Developer options dan USB debugging, sambungkan kabel data,
   buka kunci HP, lalu setujui dialog RSA. Beberapa OEM memerlukan izin tambahan
   untuk input lewat USB debugging.
4. Aplikasi terpasang. Tool tidak membangun/menginstal APK, mengubah izin GPS,
   atau memasukkan data contoh ke workspace.

Default memilih **satu HP USB** menggunakan `adb -d`, lalu mengunci serial
untuk seluruh aksi tersebut. Jika ada beberapa HP, tentukan `--serial`.
Emulator atau ADB jaringan hanya dipakai jika serialnya diberikan eksplisit.
Perangkat unauthorized/offline dan pilihan ambigu menghasilkan error.

## CLI tanpa dependensi Python tambahan

Jalankan dari root repo:

```powershell
python tools/vision_windows.py devices
python tools/vision_windows.py screenshot
python tools/vision_windows.py launch --package com.example.cpi --wait-ms 1500
```

Output JSON memuat path PNG, `width`, `height`, serial dan status.
**Buka PNG terlebih dahulu**, pilih koordinat berdasarkan gambar, lalu jalankan
satu aksi. Contoh koordinat berikut hanya ilustrasi; sesuaikan dengan layar aktual:

```powershell
python tools/vision_windows.py tap --x 540 --y 1800
python tools/vision_windows.py swipe --x 540 --y 1800 --x2 540 --y2 700 --duration-ms 450
python tools/vision_windows.py long_press --x 540 --y 900 --duration-ms 800
python tools/vision_windows.py text --text 'E2E Kopi'
python tools/vision_windows.py key --key BACK
python tools/vision_windows.py screenshot --serial GANTI_DENGAN_SERIAL_HP
```

Titik `(0,0)` adalah kiri atas **PNG asli**, dalam pixel fisik, bukan logical
pixel Flutter. Jika preview diperkecil, konversikan koordinatnya:
`x_asli = x_preview * width_asli / width_preview` (sama untuk y). Jangan memakai
koordinat gambar lama setelah navigasi, rotasi atau keyboard berubah. Koordinat
di luar layar ditolak sebelum input dikirim.

Setiap aksi UI mengembalikan PNG baru setelah `--wait-ms` (default 500, maksimum
10000). Delay ini tidak membuktikan loading selesai: ambil screenshot lagi jika
hasil masih loading. `long_press` minimal 600 ms. Input teks mendukung ASCII
cetak dan spasi; Unicode, newline dan literal `%s` ditolak secara eksplisit.
Karakter shell di-quote pada shell Android. Gunakan keyboard perangkat untuk
teks di luar dukungan tersebut. `text` mengetik pada field yang sudah fokus.

## Server MCP untuk agent vision

CLI memakai standard library. Mode MCP memakai
[SDK Python MCP resmi](https://github.com/modelcontextprotocol/python-sdk/tree/v1.x):

```powershell
python -m pip install -r tools/vision_windows.requirements.txt
python tools/vision_windows.py serve
```

`serve` berjalan lewat stdio; tidak membuka port HTTP. Client MCP menjalankannya
sebagai subprocess. Tool yang diekspos bernama **`vision_windows`**. Hasil UI
berisi metadata teks dan `image/png` base64 sebagai MCP ImageContent, sehingga
agent menerima gambar langsung tanpa harus membuka path lokal sendiri.

Untuk mendaftarkan di Codex dari root repo (gunakan interpreter Python yang
memiliki SDK tersebut):

```powershell
$visionScript = (Resolve-Path tools/vision_windows.py).Path
$visionPython = (Get-Command python).Source
codex mcp add vision_windows -- $visionPython $visionScript serve
codex mcp get vision_windows
```

Untuk mengunci HP tertentu, tambahkan `--serial SERIAL_HP` setelah `serve` saat
mendaftar. Gunakan `--adb PATH_ADB_EXE` jika PATH SDK tidak diteruskan client.
Konfigurasi ini memakai path absolut agar bisa dijalankan dari direktori mana
pun. Setelah mendaftar, buka sesi Codex baru/restart client agar tool dimuat.
Lihat [panduan MCP Codex](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).

Client MCP lain bisa menggunakan konfigurasi setara:

```json
{
  "mcpServers": {
    "vision_windows": {
      "command": "C:/Python314/python.exe",
      "args": ["C:/Users/Xvis/cpi/tools/vision_windows.py", "serve"]
    }
  }
}
```

Sesuaikan path pada mesin lain.

### Muse Code dan Antigravity CLI (`agy`)

Pada mesin ini server juga didaftarkan di:

- Muse: `C:/Users/Xvis/.config/muse/settings.json`, di bawah `mcpServers.vision_windows`.
- agy: `C:/Users/Xvis/.gemini/config/mcp_config.json`, di bawah `mcpServers.vision_windows`.

Keduanya memakai interpreter, script dan ADB absolut yang sama. Entry Muse
memakai `framing: "line_delimited_json"`. Environment `USERPROFILE` dan
`LOCALAPPDATA` diteruskan agar ADB menemukan profil Windows/kunci USB debugging;
Muse membatasi environment subprocess secara default. Konfigurasi lama dibackup
dengan suffix `.vision_windows.<timestamp>.bak` di sebelah file asal.

Untuk agy, perintah pendaftaran setara:

```powershell
agy mcp add --env USERPROFILE=C:/Users/Xvis --env LOCALAPPDATA=C:/Users/Xvis/AppData/Local vision_windows -- C:/Python314/python.exe C:/Users/Xvis/cpi/tools/vision_windows.py serve --adb C:/Users/Xvis/AppData/Local/Android/Sdk/platform-tools/adb.exe
agy mcp list
```

Mulai sesi Muse baru lalu periksa `/mcp`; di agy, buka `/mcp` dan reload server
atau mulai sesi baru. Format/lokasi konfigurasi mengikuti
[panduan Muse](https://meta-models.github.io/muse-code-sdk/next/guides/extend/mcp-servers/)
dan [panduan Antigravity](https://antigravity.google/docs/mcp).

Verifikasi lokal: konfigurasi keduanya berhasil dipakai untuk handshake MCP,
tool discovery dan pemanggilan `devices` (Muse diuji dengan environment
subprocess terbatas). HP sudah tidak terhubung saat pemeriksaan ini. Smoke
PNG/input USB sebelumnya berhasil pada RMX3867. Pemuatan tool di sesi interaktif
Muse/agy yang sudah terbuka tetap membutuhkan reload/sesi baru.

### Pemanggilan tool

Contoh argumen tool:

```json
{"action": "screenshot"}
```

```json
{"action": "tap", "x": 540, "y": 1800, "wait_ms": 700}
```

Alur agent: **screenshot → lihat gambar → satu aksi → lihat gambar hasil →
assert kondisi yang benar-benar terlihat**. Agent vision berasal dari client;
server ini tidak memanggil model AI/API terpisah.

## Bukti dan batas verifikasi

PNG dan metadata JSON disimpan unik di `outputs/vision_windows/` yang sudah
diabaikan Git. `action_sent: true` hanya berarti perintah berhasil dikirim;
`visual_assertion: pending_agent_review` tetap menuntut pemeriksaan gambar.
Server tidak otomatis menyatakan tes E2E lulus. Jika screenshot gagal setelah
input, error menyebut aksi mungkin/sudah terkirim: ambil gambar ulang sebelum
mengulangi aksi agar tidak menggandakan transaksi.

Metadata tidak merekam teks yang diketik. Screenshot tetap dapat memuat data
pribadi dan field yang terlihat. Hindari kredensial lewat argumen CLI karena
dapat masuk shell history/process list; gunakan input MCP atau keyboard HP.
Layar dengan proteksi capture bisa hitam; tool tidak melewati proteksi Android.

Untuk Rangkai, verifikasi gerbang GPS, navigasi lima tab, form, error dan hasil
simpan pada akun/workspace tes yang sesuai. Screenshot pesan sukses saja tidak
membuktikan round-trip Supabase, persistensi, GPS akurat atau upload kamera.
Build Flutter dan integration test tetap pemeriksaan terpisah.

Tes tool (mock ADB + format hasil MCP):

```powershell
python -m unittest discover -s tools -p test_vision_windows.py -v
```
