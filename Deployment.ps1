<#
.SYNOPSIS
    This script is used to automate and deploy a configured Windows AD Domain environment

.DESCRIPTION
    This script will automate the provisioning and deployment of a basic fully functional windows domain environment - including Domain Controllers/DNS/DHCP/File Share on a Windows Hyper-V Host

.EXAMPLE
    #TBD

.LINK
    https://github.com/rusthawk/Rusthawk-Deployment

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
    [String]$DeployShare = "\\hawkwing\dsc\Rusthawk-Deployment"
    )


#---------------------------------#
#Setup and Path/Dir Config
#---------------------------------#


$ConfigPath  = Join-Path -Path $PSScriptRoot -ChildPath "Deploy"
$NodeConfigs = Join-Path -Path $ConfigPath   -ChildPath "Nodes"
$HVConfigs   = Join-Path -Path $PSScriptRoot -ChildPath "HyperV"

Remove-Item $ConfigPath -Force -Recurse

if(-not (Test-Path $ConfigPath)) {
    New-Item -Path $ConfigPath -ItemType Directory -Force
}

if(-not (Test-Path $NodeConfigs)) {
    New-Item -Path $NodeConfigs -ItemType Directory -Force
}

#---------------------------------#
#Config Generation Block
#---------------------------------#
$ConfigData = & "$PSScriptRoot\ConfigurationData.ps1" -DSCResourcePath "" -HyperVHost hawkwing

#Mainly for testing - ensure an outdated version of DeploymentConfig isn't loaded
Remove-Module DeploymentConfiguration -ErrorAction Ignore

Import-Module $PSScriptRoot\DeploymentConfiguration.psm1

PullServer    -ConfigurationData $ConfigData -Role 'PullServer'   -OutputPath $ConfigPath\PullServer

PullNode      -ConfigurationData $ConfigData -Role 'PullNode'     -OutputPath $NodeConfigs

#DomainController       -ConfigurationData $ConfigData -Role 'PDC'          -OutPath $NodeConfigs
#DomainController       -ConfigurationData $ConfigData -Role 'DC'           -OutPath $NodeConfigs
#FileServer             -ConfigurationData $ConfigData -Role 'FileServer'   -OutPath $NodeConfigs

#Generate DSC Checksum for configs for DSC Pull
New-DSCCheckSum -ConfigurationPath $NodeConfigs -OutPath $NodeConfigs

#Deploy Node files to HyperVisor via Windows Share
Copy-Item -Path $ConfigPath -Recurse -Destination $DeployShare -Force

#-------------------------------------------#
#Generate and Push HyperV/VM Configurations
#-------------------------------------------#

HyperVHost     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $HVConfigs
Start-DSCConfiguration -Path $HVConfigs -Force -Wait -Verbose

PullServerVM   -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $HVConfigs
Start-DSCConfiguration -Path $HVConfigs -Force -Wait -Verbose

#This guy is just for testing
PullNodeVM     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $HVConfigs
Start-DSCConfiguration -Path $HVConfigs -Force -Wait -Verbose

