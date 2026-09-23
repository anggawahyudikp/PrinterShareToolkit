param([string]$OutputDirectory)
$ErrorActionPreference='Stop'

$root=Split-Path -Parent $PSScriptRoot
$legacyGuide=Join-Path $root 'Docs\PANDUAN_PENGGUNAAN.md'
if(Test-Path -LiteralPath $legacyGuide){
    throw 'The legacy Indonesian user guide is still present.'
}

$files=@(
    '.github/ISSUE_TEMPLATE/bug_report.yml',
    '.github/ISSUE_TEMPLATE/config.yml',
    '.github/ISSUE_TEMPLATE/feature_request.yml',
    '.github/pull_request_template.md',
    '.github/workflows/ci.yml',
    'README.md',
    'CHANGELOG.md',
    'CONTRIBUTING.md',
    'SECURITY.md',
    'Core/Launcher.ps1',
    'Core/Toolkit.ps1',
    'Docs/FLOWCHART.md',
    'Docs/GITHUB_PUBLISH_CHECKLIST.md',
    'Docs/PROVENANCE.md',
    'Docs/TROUBLESHOOTING.md',
    'Docs/USER_GUIDE.md',
    'PrinterToolkit.bat',
    'scripts/Build-Release.ps1'
)

$indonesianWords=@(
    'akun','anda','apakah','batal','bawaan','belum','berhasil','bermasalah',
    'buat','dengan','dihentikan','dijalankan','dikonfirmasi','diperlukan',
    'diterapkan','diterima','ditolak','gagal','hapus','hasil','jangan','jika',
    'karena','kata sandi','kembali','koneksi lama','lalu','lokal','masih',
    'memakai','membuat','mencegah','mencoba','mengabaikan','mengandung',
    'menggunakan','menjadi','menetapkan','nomor printer','pilih','pilihan',
    'sebelum','sehat','selesai','setelah','sudah','tersedia','tidak','untuk',
    'yang'
)
$pattern='\b(?:'+(($indonesianWords | ForEach-Object {[regex]::Escape($_)}) -join '|')+')\b'
$hits=New-Object 'System.Collections.Generic.List[string]'

foreach($relative in $files){
    $path=Join-Path $root ($relative -replace '/','\')
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "English audit file is missing: $relative"}
    $lineNumber=0
    foreach($line in [IO.File]::ReadLines($path)){
        $lineNumber++
        if($line -match $pattern){$hits.Add("${relative}:${lineNumber}: $($line.Trim())")}
    }
}

if($hits.Count){
    throw ("Possible Indonesian text remains:`n"+($hits -join "`n"))
}

Write-Host 'PASS: public text files and toolkit messages pass the English-only language audit.'
return 2
