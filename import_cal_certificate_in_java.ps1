Set-StrictMode -Version Latest

[String]$CertificateTemporaryPath = "C:\Temp\CertificateExportPath\"
 
If (Test-Path $CertificateTemporaryPath)
    { Remove-Item -Recurse -Force $CertificateTemporaryPath }
New-Item $CertificateTemporaryPath -ItemType Directory | Out-Null
 
$AllCerts = Get-ChildItem Cert:\ -Recurse
 
Foreach ($Cert In $AllCerts)
{
    if (( [bool]($Cert.psobject.Properties | where { $_.Name -eq "Subject"})) -And ($Cert.Subject -eq "CN=**********")) {
        
        [String]$certificateThumbprint=$Cert.Thumbprint
        [String]$certificatePath="$CertificateTemporaryPath\\$certificateThumbprint"
        [String]$StoreLocation = ($Cert.PSParentPath -Split '::')[-1]
        Write-Host Exporting $Cert."Subject"
        # Export The Targeted Cert In Bytes For The CER format
        $CertToExportInBytesForCERFile = $Cert.export("Cert")

        # Write The Files Based Upon The Exported Bytes
        [system.IO.file]::WriteAllBytes($certificatePath, $CertToExportInBytesForCERFile)
    }
}