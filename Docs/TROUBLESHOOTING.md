# Troubleshooting

## TCP 445 = False

Kemungkinan:
- Routing antar subnet belum tersedia.
- Firewall memblokir SMB.
- HOST tidak reachable.
- File and Printer Sharing belum aktif.

Cek routing, firewall, dan konektivitas HOST sebelum mencoba install printer.

## TCP 135 = False

RPC tidak reachable. Cek firewall/routing HOST dan CLIENT.

## SMB error 1326

Username/password salah.

Toolkit harus **STOP**. Jangan menambahkan retry password otomatis karena dapat memicu account lockout.

## SMB error 1909

Account HOST sedang locked out. Unlock account RID 500 di HOST sebelum retry.

## SMB error 1219

Ada credential/session conflict ke server yang sama. Bersihkan session/credential lama lalu pairing ulang satu kali.

## Error 0x00000006

Standard shared-printer connection gagal membuat connection object.

Flow toolkit:
1. SSR + `PrintUIEntry /in` dicoba sekali.
2. Jika connection tidak terbentuk, toolkit berpindah ke Native Local Port UNC.
3. Toolkit tidak menjalankan installer `/in` kedua secara paralel.

## Error 0x000007D1 — The specified driver is invalid

Indikasi umum: registrasi/rendering driver Windows V3 bermasalah.

Langkah diagnosis:
- Buat queue lokal menggunakan driver yang sama ke port `FILE:`.
- Jika queue lokal juga menghasilkan `0x7D1`, fokus ke driver/core V3 CLIENT.
- Re-register driver secara terkontrol; jangan langsung mengubah HOST.

## PrinterStatus = PendingDeletion

Toolkit mencoba:
- Membersihkan job target secara best effort.
- Release `PrintIsolationHost` / `splwow64` bila perlu.
- Cycle Print Spooler.
- Mengabaikan stale queue dan membuat replacement queue jika Windows belum menghapus object lama.

## Spooler tidak Running

Toolkit memakai polling terkontrol. Jika Spooler gagal `Running` setelah timeout, proses berhenti dengan `[FAIL]`.

Jangan melakukan loop restart tanpa batas.

## ShareName berbeda dengan display name

Gunakan **ShareName** yang terlihat melalui `net view \\HOST`, bukan hanya nama display printer di Settings/Control Panel.

## Sebelum membuat GitHub issue

Sanitasi data berikut:
- Password / credential.
- Hostname internal.
- IP internal bila tidak perlu.
- Nama user/domain/perusahaan.
- Isi `Profiles\` dan `Logs\` yang sensitif.

Sertakan:
- Toolkit version.
- Windows build HOST dan CLIENT.
- Printer model.
- Driver name/version.
- Error code.
- Metode yang gagal (`/in` atau Local Port fallback).
- Log yang sudah disanitasi.
