# Printer Share Toolkit v1.1.2
## Panduan Penggunaan

TUJUAN
Toolkit ini digunakan untuk setup, repair, connect, diagnostic, dan cleanup printer sharing native Windows.

Metode utama CLIENT:
1. SSR + PrintUIEntry /in
2. Jika gagal, Native Local Port UNC sebagai fallback

Toolkit tidak menggunakan PaperCut.



## A. SEBELUM MULAI
1. Extract seluruh isi ZIP ke folder biasa.
   Contoh:
   C:\PrinterShareToolkit_v1.1.2

2. Jangan menjalankan Toolkit.ps1 langsung.
   Jalankan:
   PrinterToolkit.bat

3. Tool akan meminta hak Administrator/UAC secara otomatis.

4. Pastikan HOST dan CLIENT dapat saling terhubung melalui jaringan.
   Port utama:
   - TCP 445 : SMB
   - TCP 135 : RPC

5. Untuk HOST, Built-in Administrator RID 500 wajib READY.
   Local admin lain tidak dianggap pengganti RID 500.



## B. MAIN MENU
[1] Setup / Repair Printer HOST
    Menyiapkan PC yang printer fisiknya terpasang langsung.

[2] Connect / Repair Printer CLIENT
    Menghubungkan PC CLIENT ke printer yang dishare oleh HOST.

[3] Built-in Administrator Readiness
    Mengecek kesiapan Built-in Administrator RID 500.

[4] Full Diagnostic
    Audit jaringan, service, printer, driver, SMB, SSR, dan kondisi terkait.

[5] Cleanup Printer Queue
    Membersihkan job/queue printer yang bermasalah.

[6] Test Print
    Menjalankan test print pada printer yang dipilih.

[7] Windows/SAM Health Check
    Audit read-only untuk kondisi Windows/SAM dan Built-in Administrator.

[T] Technician View
    OFF = tampilan ringkas.
    ON  = tampilkan detail teknis lebih lengkap.

[L] Open Logs Folder
    Membuka folder log toolkit.

[0] Exit
    Keluar dari toolkit.



## C. SETUP PRINTER HOST
Gunakan Menu [1] pada PC yang printer fisiknya terhubung langsung melalui USB/LPT/TCP-IP lokal.

Flow:
1. Toolkit mengecek Built-in Administrator RID 500.
2. Jika Disabled, toolkit menawarkan Enable.
3. Jika Locked, toolkit menawarkan Unlock.
4. Jika password belum READY, toolkit meminta Set/Reset password.
5. Pilih printer LOCAL yang akan dishare.
6. Toolkit menolak printer Type=Connection agar tidak membuat share berantai.
7. Toolkit membuat backup registry printer.
8. Toolkit membuat/repair printer share.
9. SSR diaktifkan.
10. Firewall File and Printer Sharing disiapkan.
11. Print Spooler direstart secara terkontrol.
12. Host Profile dibuat di folder Profiles\ tanpa menyimpan password.
13. Final check dijalankan.

Target akhir:
[OK] RID500 READY
[OK] Printer Local
[OK] Printer Shared
[OK] SSR
[OK] Spooler Running
[OK] TCP 445

CATATAN:
- Jika toolkit meminta ShareName, gunakan nama singkat dan jelas.
- Hindari karakter aneh pada ShareName.
- Contoh: EPSONL3210, LX310, XPRINTER.



## D. CONNECT / REPAIR CLIENT
Gunakan Menu [2] pada PC yang akan menggunakan printer dari HOST.

Input utama:
- Host IP / hostname
- Printer ShareName

Contoh:
Host IP      : 192.168.10.10
ShareName    : EPSON-L3210

Flow:
1. Preflight TCP 445 / TCP 135.
2. Aktifkan policy SSR di CLIENT.
3. Gunakan credential Built-in Administrator RID 500 HOST.
4. Credential test hanya SATU kali untuk mencegah account lockout.
5. Verifikasi SMB dan printer share.
6. Primary install menggunakan:
   PrintUIEntry /in
7. Jika berhasil:
   Toolkit menggunakan koneksi printer standard Windows + SSR.
8. Jika /in gagal:
   Toolkit mencoba Native Local Port UNC menggunakan driver native CLIENT.
9. Final health check dijalankan.

Metode PRIMARY:
\HOST\Share
-> Point-and-Print
-> SSR

Metode FALLBACK:
Driver native CLIENT
-> Local Port \\HOST\Share
-> HOST Spooler
-> Printer

Fallback tetap native Windows dan bukan PaperCut.



## E. BUILT-IN ADMINISTRATOR RID 500
Toolkit mencari account berdasarkan SID yang berakhiran -500.
Nama account boleh pernah di-rename.

RID 500 WAJIB untuk HOST setup.

Kondisi READY:
- Account ditemukan
- Enabled
- Tidak Locked
- Password READY

Jika salah satu belum READY, HOST Setup tidak diteruskan sampai diperbaiki.

Local account lain meskipun member Administrators tidak menggantikan requirement RID 500.


F. NORMAL VIEW vs TECHNICIAN VIEW
NORMAL VIEW
- Default
- Output ringkas
- Cocok untuk vendor/user lapangan
- Fokus pada OK / WARN / FAIL

TECHNICIAN VIEW
- Tekan T dari Main Menu
- Menampilkan detail tambahan
- Cocok untuk troubleshooting
- Raw diagnostic tetap tersimpan di Logs\

Status:
[OK]   = berhasil
[WARN] = ada kondisi yang perlu diperhatikan
[FAIL] = proses gagal / requirement tidak terpenuhi
[..]   = sedang diproses
[-]    = dilewati / tidak diperlukan



## G. STATUS AKHIR
READY
Printer siap digunakan dan kondisi utama lolos.

DEGRADED
Printer ditemukan/terpasang, tetapi ada health check yang belum ideal.

FAILED
Instalasi/koneksi printer tidak berhasil.

Jika FALLBACK Local Port dipakai, itu bukan berarti printer gagal.
Toolkit hanya berpindah dari metode standard Point-and-Print ke metode native Local Port.



## H. TEST PRINT
Gunakan Menu [6].

Test print sebaiknya dilakukan setelah status READY.

Jika test print gagal:
1. Cek printer fisik ON/Ready.
2. Cek kertas/tinta/toner.
3. Cek queue HOST.
4. Jalankan Full Diagnostic.
5. Aktifkan Technician View bila perlu.



## I. FULL DIAGNOSTIC
Gunakan Menu [4] jika:
- Printer tidak connect
- Printer connect tapi tidak print
- SMB gagal
- Driver bermasalah
- Spooler bermasalah
- Queue PendingDeletion
- SSR tidak aktif
- HOST/CLIENT tidak saling melihat

Simpan screenshot hasil atau file log jika perlu dianalisis lebih lanjut.



## J. CLEANUP PRINTER QUEUE
Gunakan Menu [5] bila:
- Job print stuck
- Printer status tidak berubah
- Queue PendingDeletion
- Job lama menghalangi printer baru

Toolkit menghindari purge global yang agresif dan berusaha membersihkan secara terkontrol.



## K. ERROR UMUM
1. TCP 445 = False
   Kemungkinan:
   - Routing antar subnet belum ada
   - Firewall memblokir SMB
   - HOST tidak reachable

   Action:
   - Cek ping/routing
   - Cek firewall
   - Cek File and Printer Sharing

2. TCP 135 = False
   Kemungkinan RPC diblokir.

3. SMB error 1326
   Username/password salah.
   Toolkit STOP dan tidak retry berkali-kali.

4. SMB error 1909
   Account HOST locked.
   Unlock RID 500 di HOST sebelum mencoba lagi.

5. SMB error 1219
   Ada credential/session SMB lain ke HOST yang sama.
   Cleanup session/credential lama terlebih dahulu.

6. PrintUIEntry /in gagal / error 0x00000006
   Toolkit akan mencoba Native Local Port fallback bila driver native tersedia.

7. Error 0x000007D1 - The specified driver is invalid
   Biasanya terkait driver/rendering V3 pada CLIENT.
   Gunakan Full Diagnostic / repair driver native CLIENT.

8. PendingDeletion
   Toolkit akan mencoba melepas job/proses terkait, cycle Spooler, dan membuat queue pengganti jika diperlukan.

9. Spooler gagal start
   Toolkit menunggu maksimal 30 detik lalu memberikan FAIL yang jelas.
   Gunakan Full Diagnostic untuk pengecekan lanjutan.



## L. FILE DAN FOLDER TOOLKIT
PrinterToolkit.bat
- Launcher utama.

Core\Toolkit.ps1
- Engine toolkit.

Profiles\
- Host Profile JSON.
- Tidak menyimpan password.

Backup\
- Backup registry printer HOST sebelum perubahan tertentu.

Logs\
- Log eksekusi toolkit.

README.md
- Ringkasan teknis.

Docs\FLOWCHART.md
- Alur internal toolkit.

Docs\PANDUAN_PENGGUNAAN.md
- Panduan ini.



## M. REKOMENDASI PENGGUNAAN
Untuk setup baru:
HOST  -> Menu 1
CLIENT -> Menu 2
Test   -> Menu 6

Jika gagal:
Menu 4 Full Diagnostic
-> aktifkan Technician View jika perlu
-> cek Logs\

Jangan menjalankan beberapa instance toolkit pada PC yang sama secara paralel saat sedang install/repair printer.

### Rollback HOST

Menu `[8] Rollback Last HOST Setup` memulihkan perubahan yang reversible:

- Shared state, ShareName, izin printer, dan RenderingMode sebelumnya.
- Status firewall File and Printer Sharing yang direkam sebelum setup.
- RID-500 dinonaktifkan kembali hanya bila transaksi tersebut yang mengaktifkannya.

Reset password dan unlock account tidak dapat dikembalikan secara aman. Kondisi tersebut dicatat sebagai non-reversible dan ditampilkan sebelum rollback.



## N. SECURITY
- Password tidak ditulis ke Host Profile.
- Credential CLIENT dapat disimpan di Windows Credential Manager.
- Credential test dibuat satu kali untuk mengurangi risiko account lockout.
- Jangan membagikan Logs / Profiles kepada pihak yang tidak memerlukan akses.
- Gunakan hanya pada PC yang Anda kelola / memiliki izin administrasi.


QUICK START
HOST:
1. Run PrinterToolkit.bat
2. Menu 1
3. Pastikan RID500 READY
4. Pilih printer Local
5. Tentukan ShareName
6. Tunggu RESULT READY

CLIENT:
1. Run PrinterToolkit.bat
2. Menu 2
3. Isi Host IP/Hostname
4. Isi ShareName
5. Masukkan credential RID500 HOST
6. Tunggu RESULT READY
7. Menu 6 untuk Test Print
