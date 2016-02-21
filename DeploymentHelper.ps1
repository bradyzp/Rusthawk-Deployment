
<#
    .SYNOPSIS
    Generate unattend.xml files for VM Deployment

    ScratchPad:
    Skip all EULA warnings/bullshit
    Variably want to be able to apply synchronous log on commands
    Set a computername other than the auto generated WIN-!@#!
    Set the timezone and locality of the computer


#>

function GenerateUnattend {
    [CmdletBinding()]
    param (

        [string]$ComputerName,

        [switch]$SkipEULA = $True,

        [string]$FirstLoginScript,

        [Switch]$Autologon,
        [String]$AdminPasswd,

        [string]$TimeZone,
        
        #Provide hashtable of "command : order"
        [Hashtable[]]$LogonCommand
    )

#Synchronous Command Block
    $synccommand = @"
    <SynchronousCommand wcm:action="add">
        <CommandLine>{0}</CommandLine>
        <Description>Synchronous Command{1}</Description>
        <Order>{1}</Order>
    </SynchronousCommand>
"@
    
    $command = ''
    $LogonCommand | % {
        $command += $synccommand -f $_.Command,$_.Order
    }

    #Compile the synchronous commands into the FirstLogonCommands block
    $FirstLogonCommands = @"
    <FirstLogonCommands>
        {0}
    <FirstLogonCommands>
"@ -f $command

#OOBE Block
    $oobe = @"
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <FirstLogonCommands>
                {0}
            </FirstLogonCommands>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
            </OOBE>
            <RegisteredOwner>Rusthawk.net</RegisteredOwner>
            <RegisteredOrganization>Rusthawk.net</RegisteredOrganization>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>dABlAHMAdABwAGEAcwBzAHcAbwByAGQAQQBkAG0AaQBuAGkAcwB0AHIAYQB0AG8AcgBQAGEAcwBzAHcAbwByAGQA</Value>
                    <PlainText>false</PlainText>
                </AdministratorPassword>
            </UserAccounts>
        </component>
        </component>
"@ -f $FirstLogonCommands

#Specialize block
    $specialize = @"
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <AutoLogon>
                <Password>
                    <Value>$AdminPasswd</Value>
                    <PlainText>true</PlainText>
                </Password>
                <LogonCount>10</LogonCount>
                <Username>administrator</Username>
                <Enabled>true</Enabled>
            </AutoLogon>
            <ComputerName>$ComputerName</ComputerName>
        </component>
"@

$specialize_pass = @"
    <settings pass="specialize">
    {0}
    </settings>
"@ -f $specialize

$oobeSystem_pass = @"
    <settings pass="oobeSystem">
    {0}
    </settings>
"@ -f $oobe


####
#UnattendStruct provides the basis for the unattend.xml structure - other blocks are formatted into it.
####
    $UnattendXML = @"
<?xml version="1.0" encoding="utf-8"?>
    <unattend xmlns="urn:schemas-microsoft-com:unattend">
        {0}
        {1}
    <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
"@ -f $specialize,$oobe

    $UnattendXML
}

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