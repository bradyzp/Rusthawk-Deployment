<#
    .SYNOPSIS
    Collection of functions to assist Deployment.ps1 with various tasks

#>

function GenerateCredentials {
    


}

function GenerateDSCCert {
    $CertDNSName = 'DSCEncryptionCert'
    $StoreLocation = "LocalMachine"

    Get-ChildItem Cert:\$StoreLocation\My | ? Subject -eq "CN=$CertDNSName" | Remove-Item -ErrorAction SilentlyContinue

    New-SelfSignedCertificate -KeyUsage KeyEncipherment -KeyFriendlyName $CertDNSName -CertStoreLocation Cert:\$StoreLocation\My -DnsName $CertDNSName -Provider 'Microsoft Strong Cryptographic Provider' | out-null


    $Thumb = Get-ChildItem Cert:\$StoreLocation\My | ? Subject -eq "CN=$CertDNSName" | select -ExpandProperty Thumbprint
    $Thumb
    Export-PfxCertificate -Cert (Get-ChildItem Cert:\$StoreLocation\My)[0] -FilePath 'C:\Dev\dscencryptioncert.pfx' -Password ((Get-Credential -Message 'PKey Password' -UserName 'PFX').Password) | Out-Null
    Export-Certificate -Cert (Get-ChildItem Cert:\$StoreLocation\My | ? Subject -eq "CN=$CertDNSName")[0] -FilePath 'C:\Dev\dscencryptioncert.cer' | Out-Null
}
GenerateDSCCert