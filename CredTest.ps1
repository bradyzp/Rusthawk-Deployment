function Import-Credentials {
    param (
        [Parameter(Mandatory, Position=0)]
        [String]$Username,
        [String]$CredStore = "$PSScriptRoot\Resources\Creds"
    )
    if(-not (Test-Path $CredStore)) {
        mkdir $CredStore
    }
    try {
        Write-Verbose "Importing Credential for user $Username"
        $credential = Import-Clixml -Path "$CredStore\$username.clixml" -Verbose

    } catch {
        
        $credential = Get-Credential -Message "Supply Credentials for user: $Username" -UserName $Username
        Write-Verbose "Exporting new credential for user $Username"
        $credential | Export-Clixml -Path "$CredStore\$username.clixml"
    }

    $credential
    $credential.GetNetworkCredential().Password
}

Import-Credentials -verbose 'bradyzp3
'