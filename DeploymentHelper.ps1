
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
        [String]$LoginAccount,
        [String]$LoginPasswd,

        [string]$TimeZone,
        
        [Hastable]$LogonCommand


    )

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
    $firstlogoncommands = @"
    <FirstLogonCommands>

    <FirstLogonCommands>
"@ -f $command

    $unattendStruct = @"
    <?xml version="1.0" encoding="utf-8"?>
        <unattend xmlns="urn:schemas-microsoft-com:unattend">
            <settings pass="specialize">
            {0}
            </settings>
            <settings pass="oobeSystem">
            {1}
            </settings>
        <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
    </unattend>

    $specialize = @"
    <?xml version="1.0" encoding="utf-8"?>
        <unattend xmlns="urn:schemas-microsoft-com:unattend">
            <settings pass="specialize">
                <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <ComputerName>$Computername</ComputerName>
                    <RegisteredOrganization>$Organization</RegisteredOrganization>
                    <RegisteredOwner>$Owner</RegisteredOwner>
                    <TimeZone>$Timezone</TimeZone>
                </component>
"@

    $oobe = @"
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <UserAccounts>
            <AdministratorPassword>
                <Value>$Adminpassword</Value>
                <PlainText>true</PlainText>
            </AdministratorPassword>
        </UserAccounts>
        $firstlogoncommands
	    <AutoLogon>
	        <Password>
	            <Value>$Adminpassword</Value>
	            <PlainText>true</PlainText>
	        </Password>
	    <Username>administrator</Username>
	    <LogonCount>1</LogonCount>
	    <Enabled>true</Enabled>
	    </AutoLogon>
        <OOBE>
            <HideEULAPage>true</HideEULAPage>
            <SkipMachineOOBE>true</SkipMachineOOBE>
        </OOBE>
    </component>
"@

    $unattendXML = $unattendStruct -f $specialize,$oobe

}

function GenerateCredentials {
    


}