<#
    .SYNOPSIS
    Collection of functions to assist Deployment.ps1 with various tasks

#>



function Select-ModuleBase {
    param (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]]$ResourceInfo,
        [Parameter(ParameterSetName='DSCName')]
        [string]$Name,
        [Parameter(ParameterSetName='DSCModule')]
        [string]$Module
    )
    if($Name) {
        $ResourceBase = ($ResourceInfo | Where-Object Name -eq $Name).Module.ModuleBase
    }
    else {
        $ResourceBase = ($ResourceInfo | Where-Object Module -Like $Module | Select -First 1).Module.ModuleBase
    }
    $ResourceBase
}

function GenerateCredentials {
    


}

function New-DSCCertificate {
    param (
        [Parameter(Mandatory)]
        [string]$CertName,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [ValidateSet('LocalMachine','CurrentUser')]
        [string]$CertStore = "CurrentUser",
        [Parameter(Mandatory)]
        [pscredential]$PrivateKeyCred
    )

    Get-ChildItem Cert:\$CertStore\My | ? Subject -eq "CN=$CertName" | Remove-Item -ErrorAction SilentlyContinue

    New-SelfSignedCertificate -KeyUsage KeyEncipherment -KeyFriendlyName $CertName -CertStoreLocation "Cert:\$CertStore\My" -DnsName $CertName -Provider 'Microsoft Strong Cryptographic Provider' | out-null

    $Thumbprint = Get-ChildItem Cert:\$CertStore\My | ? Subject -eq "CN=$CertName" | select -ExpandProperty Thumbprint
    
    Export-PfxCertificate -Cert (Get-ChildItem Cert:\$CertStore\My)[0] -FilePath "$OutputPath\$CertName.pfx" -Password ($PrivateKeyCred.Password) | Out-Null
    Export-Certificate -Cert (Get-ChildItem Cert:\$CertStore\My | ? Subject -eq "CN=$CertName")[0] -FilePath "$OutputPath\$CertName.cer" | Out-Null

    #Remove the PrivateKey from host machine
    Get-ChildItem Cert:\$CertStore\My | ? Subject -eq "CN=$CertName" | Remove-Item -ErrorAction SilentlyContinue | Out-Null
    #Import the Public key into the store
    Import-Certificate -FilePath "$OutputPath\$CertName.cer" -CertStoreLocation Cert:\$CertStore\My | Out-Null

    return $Thumbprint
}
