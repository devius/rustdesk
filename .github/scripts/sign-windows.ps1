# Authenticode-sign every unsigned .exe/.dll/.msi under a directory with the PFX
# from WINDOWS_PFX_BASE64 / WINDOWS_PFX_PASSWORD. Files already signed by someone
# else (e.g. Microsoft runtime DLLs) are left untouched.
param([Parameter(Mandatory)][string]$Dir)
$ErrorActionPreference = 'Stop'

$pfx = Join-Path $env:RUNNER_TEMP 'sign.pfx'
[IO.File]::WriteAllBytes($pfx, [Convert]::FromBase64String($env:WINDOWS_PFX_BASE64))
try {
  $signtool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.*\x64\signtool.exe" |
    Sort-Object FullName | Select-Object -Last 1
  $files = Get-ChildItem $Dir -Recurse -Include *.exe, *.dll, *.msi |
    Where-Object { (Get-AuthenticodeSignature $_.FullName).Status -eq 'NotSigned' }
  foreach ($f in $files) {
    & $signtool.FullName sign /f $pfx /p $env:WINDOWS_PFX_PASSWORD /fd sha256 `
      /tr http://timestamp.digicert.com /td sha256 /d RustDesk $f.FullName
    if ($LASTEXITCODE) { throw "signtool failed on $($f.FullName)" }
  }
  Write-Host "Signed $($files.Count) file(s) in $Dir"
} finally {
  Remove-Item $pfx -Force
}
