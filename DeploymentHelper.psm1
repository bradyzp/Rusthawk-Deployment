<#
    .SYNOPSIS
    Collection of functions to assist Deployment.ps1 with various tasks

#>

function New-MachineName {
    param (
        [Alias("Name")]
        [String]$MachineName = '<undefined>'
    )
    $GUID = ([guid]::NewGuid()).guid
    Write-Verbose "Generated GUID for $MachineName : $GUID"
    $GUID
}

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

function Import-Credential {
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$Domain,
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$Path,
        [string]$Description = "Supply Credential",
        [Switch]$Export,
        [string]$ExportFileName, #Allow a different file name than the default $Name
        [ValidateSet('clixml')]  #For future implementation of other types
        [string]$Type = 'clixml'
    )
    $FullName = $Name
    if($Domain) {
        $FullName = "$Name@$Domain"
    }
    
    $Credfile = Join-Path -Path $Path -ChildPath "$Name.$Type"
    $ExportPath = $Credfile
    if($ExportFileName) {
        $ExportPath = Join-Path -Path $Path -ChildPath "$ExportFileName.$Type"
    }
    
    if(-not (Test-Path -Path $Credfile -PathType Leaf)) {
        #Credential doesn't exist, prompt user to supply info
        Write-Warning -Message "Credential does not exist for user: $FullName"
        $Credential = Get-Credential -Message $Description -UserName $FullName
        if($Export) {
            $Credential | Export-Clixml -Path $ExportPath -Force
        }
    }
    else {
        #Credential exists, try to import
        try {
            $Credential = Import-Clixml -Path $Credfile -ErrorVariable c_err
        }
        catch {
            Write-Debug -Message "Error importing clixml file: $CredFile"
            #Maybe delete the file if it won't import then recursively call again to generate/export?
        }
    }
    $Credential
}

function Export-DSCModule {
    param (
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$ExportPath,
        [string]$Version,
        [switch]$PassThru
    )
    $Module = Get-DscResource -Module $ModuleName | Sort-Object 'Version' -Descending | Select-Object -First 1
    $ModulePath = $Module.Module.ModuleBase | Split-Path

    $Version = $Module | Select-Object -ExpandProperty 'Version'

    $PackageName = "$ModuleName`_$($Version.toString()).zip"

    $DestinationPath = Join-Path -Path $ExportPath -ChildPath $PackageName

    Compress-Archive -Path $ModulePath -DestinationPath $DestinationPath

    if($PassThru) {
        $DestinationPath
    }
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

Export-ModuleMember -Function 'Select-ModuleBase'
Export-ModuleMember -Function 'Export-DSCModule'
Export-ModuleMember -Function 'Import-Credential'
Export-ModuleMember -Function 'New-MachineName'