<#
.SYNOPSIS
    This script is used to automate and deploy a configured Windows AD Domain environment

.DESCRIPTION
    This script will automate the provisioning and deployment of a basic fully functional windows domain environment - including Domain Controllers/DNS/DHCP/File Share on a Windows Hyper-V Host

.EXAMPLE
    #TBD

.LINK
    #TBD

.NOTES
    Hyper-V Host and BaseVhd must have at least 'Windows Management Framework 5.0 Experimental July 2014 (KB2969050)' installed to run this example.  
     
    List of DSC resources that should be present on the system:
        - xIPAddress
        - xFirewall
        - xComputer
        - xADDomain
        - xADUser
        - xDhcpServerScope
        - xDhcpServerOption
        - xDhcpServerReservation
        - xDnsServerZoneTransfer
        - xDnsServerSecondaryZone
        - xDSCWebService
        - xVHD
        - xVhdFile
        - xVMHyperV
        - xVMSwitch   
#>


param (
    [String]$ConfigRoot = "config"
    )


#---------------------------------#
#Setup and Path Config
#---------------------------------#

$scriptLocation = $PSScriptRoot
$ConfigPath = Join-Path $scriptLocation $ConfigRoot
$NodeConfigs = Join-Path $ConfigPath "Nodes"
if(-not (Test-Path $NodeConfigs)) {
    mkdir $NodeConfigs
}

#---------------------------------#
#Config Generation Block
#---------------------------------#
$ConfigData = & "$scriptlocation\ConfigurationData.ps1"

Import-Module DeploymentConfiguration.psm1

PullServerVM   -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutPath $ConfigPath
PullServer     -ConfigurationData $ConfigData -Role 'PullServer'   -OutPath $ConfigPath

PullNodeVM     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutPath $ConfigPath
PullNode       -ConfigurationData $ConfigData -Role 'PullNode'     -OutPath $NodeConfigs

#DomainController       -ConfigurationData $ConfigData -Role 'PDC'          -OutPath $NodeConfigs
#DomainController       -ConfigurationData $ConfigData -Role 'DC'           -OutPath $NodeConfigs
#FileServer             -ConfigurationData $ConfigData -Role 'FileServer'   -OutPath $NodeConfigs

#Generate DSC Checksum for configs for DSC Pull
New-DSCCheckSum -ConfigurationPath $NodeConfigs -OutPath $NodeConfigs

#Need to generate HV Config last as it includes copying of all the above resources
HyperVHost -ConfigurationData $ConfigData -Role 'HyperVHost' -ResourceCopy $ConfigPath -OutPath $ConfigPath

Set-DscLocalConfigurationManager 
Start-DscConfiguration -Path $ConfigPath\HyperVHost -Wait -Force -Verbose


