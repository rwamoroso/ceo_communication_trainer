$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$certificatePath = Join-Path $scriptDir 'CEOCommunicationTrainer.cer'
$packagePath = Join-Path $scriptDir 'CEOCommunicationTrainer.msix'

Import-Module Microsoft.PowerShell.Security -ErrorAction Stop
if (-not (Get-PSDrive -Name Cert -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name Cert -PSProvider Certificate -Root '\' | Out-Null
}

Import-Certificate -FilePath $certificatePath -CertStoreLocation 'Cert:\CurrentUser\Root' | Out-Null
Add-AppxPackage -Path $packagePath
