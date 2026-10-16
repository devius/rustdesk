# Trust the Serveradmin code-signing certificate on this PC, so Windows shows
# RustDesk installers from devius/rustdesk as published by "Serveradmin".
# The certificate is limited to code signing (it cannot vouch for websites).
#
# Run in an elevated PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\install-serveradmin-cert.ps1
# Undo:
#   powershell -ExecutionPolicy Bypass -File .\install-serveradmin-cert.ps1 -Remove
param([switch]$Remove)
$ErrorActionPreference = 'Stop'

$Thumbprint = 'D14A625D0926F5789E153E017A72048502CC4905'
$CertBase64 = @'
  MIIETDCCArSgAwIBAgIJAM2Zl3lvyeSTMA0GCSqGSIb3DQEBCwUAMDkxFDASBgNVBAMMC1NlcnZl
  cmFkbWluMRQwEgYDVQQKDAtTZXJ2ZXJhZG1pbjELMAkGA1UEBhMCR0UwHhcNMjYxMDE2MDQzOTA3
  WhcNMzExMDE2MDQzOTA3WjA5MRQwEgYDVQQDDAtTZXJ2ZXJhZG1pbjEUMBIGA1UECgwLU2VydmVy
  YWRtaW4xCzAJBgNVBAYTAkdFMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAwcEzOP2V
  kewfDfAgfff9ePfajU0+hikBrWuokBoVYAGh2hbN1Vm1OAaWz7MnuU9oo8NtY97tK60Zq551Cgj/
  HuvFLvCTgm2MxElj1rc4lyk3dNXEsuyTWj73SY8atUsuJNbsGtfYIlkngu+9WbN+l/P8a58ocXyU
  615AIRjvPDRGQY8ZK0jIQFxl+C07C2o6TKdUXHbY05uA22MP9TELEFLu56VGO8bj4gBWXMJW81V9
  37d5HCaatOuyIJ4uvwFgw2IL4opzyC48aRyNEY4m4G4XBr6IyBBV/Y1gppIerROB+MjdrW7Am980
  JtIQrKfx3F2PVMNIWRXdawUne6BC8U5uyhQzkgR8RO8ZISJXlNzcPhDVTNo0WY/0bEAiLNm6wDFA
  Jsy3jOPkUJWPWif+FVpSaxICNOw8fa6u5Z+vPWu2yFLTMtoy+XFzQuUXnsX7AEiTRv52Oi5RRwtO
  3hkOq8/L0+3+sL8/90xeZDPvDAmc7+sPHpt6sdOr34VuOFaNAgMBAAGjVzBVMAwGA1UdEwEB/wQC
  MAAwDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBSq2aqL
  WiCmP8s7NAnVykGFFFvQozANBgkqhkiG9w0BAQsFAAOCAYEAGT3Pe9B8a3L+8FBAL9n6sy59VVZ2
  tNXoXuiXnBtr+No2/MEilj7XbbR5++gF9jQYa14mbQXj6XgWPmtvJVSKjIZIIKUxYIp9UT+6uIgG
  ZAOe1HXS1bYncaHdDATui5If8KXGYRSfx0boq9G7jGAfwhnMrAicV4S8r8Jmb+tUzm0o7bCDuFUl
  LXS2GxjbtVezxsD/LBCB914MER/xiQyL7HsqlxXly1ibicKDLHwH0BFVM2vdRzs2OhTwRFCN++U6
  FxCVPIThYajNjWNZsAmr+5DvigwlzjVnVuk8X1N5fSsoNBDKl6ZZn/9fGWmWYQryuO5M83BPh1+h
  4blXg8QLyNKRPLkVROXG68a0kNXwqpuc4tLzmZOsBtjH50TCV41y/tTaje1J+G742oN0L1+OFYXu
  QGRdilpNquU9NWFoNzWK5lpF5gy2BLaxabeJkyrILag6xF4BbCoQqILGu+PDNFYT9q9qnR1YUksP
  bD2k1ns0J2UCo2QWuRO1Sc/zyYQm
'@

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Run this script from an elevated (Run as administrator) PowerShell.'
}

$stores = 'Root', 'TrustedPublisher'
if ($Remove) {
  foreach ($s in $stores) {
    Get-ChildItem "Cert:\LocalMachine\$s\$Thumbprint" -ErrorAction SilentlyContinue | Remove-Item
  }
  Write-Host 'Serveradmin certificate removed.'
  return
}

$cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new(
  [Convert]::FromBase64String(($CertBase64 -replace '\s', '')))
if ($cert.Thumbprint -ne $Thumbprint) { throw "Unexpected certificate thumbprint $($cert.Thumbprint)" }

Write-Host "Subject:    $($cert.Subject)"
Write-Host "Thumbprint: $($cert.Thumbprint)"
Write-Host "Valid to:   $($cert.NotAfter)"
foreach ($s in $stores) {
  $store = [Security.Cryptography.X509Certificates.X509Store]::new($s, 'LocalMachine')
  $store.Open('ReadWrite')
  try { $store.Add($cert) } finally { $store.Close() }
}
Write-Host 'Serveradmin certificate trusted (Trusted Root + Trusted Publishers).'
