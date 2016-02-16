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

#BRANCH: LocalExecution
#Configure script for execution locall from hyper-v host - remove some complexity with pathing

param (
    #[String]$DeployShare = "\\hawkwing\dsc\Rusthawk-Deployment"
    )

#---------------------------------#
#Setup and Path/Dir Config
#---------------------------------#

#Sub folder containing any resource files required by the script - e.g. VHDx template files, generated DSC MOF files
$ResourcePath    = Join-Path -Path $PSScriptRoot    -ChildPath "Resources"
#Path to store generated node MOF files, these files are injected into VHDs to perform initial configuration tasks
$NodeConfigs     = Join-Path -Path $ResourcePath    -ChildPath "Nodes"
#Path to store xHyperV Configuration files to be executed on the Hyper-V Host, these aren't referenced by any script except this when executing Start-DSCConfiguration
$VMConfigs       = Join-Path -Path $ResourcePath    -ChildPath "VirtualMachines"

Remove-Item $DSCResourcePath -Force -Recurse

if(-not (Test-Path $DSCResourcePath)) {
    New-Item -Path $DSCResourcePath -ItemType Directory -Force
}

if(-not (Test-Path $NodeConfigs)) {
    New-Item -Path $NodeConfigs -ItemType Directory -Force
}

#---------------------------------#
#Config Generation Block
#---------------------------------#
$ConfigData = & "$PSScriptRoot\ConfigurationData.ps1" -ResourceBasePath $ResourcePath -NodeConfigs $NodeConfigs

#Mainly for testing - ensure an outdated version of DeploymentConfig isn't loaded
Remove-Module DeploymentConfiguration -ErrorAction Ignore

Import-Module $PSScriptRoot\DeploymentConfiguration.psm1

PullServer    -ConfigurationData $ConfigData -Role 'PullServer'   -OutputPath $DSCResourcePath\PullServer

PullNode      -ConfigurationData $ConfigData -Role 'PullNode'     -OutputPath $NodeConfigs
PullNodeLCM   -ConfigurationData $ConfigData -RefreshMode 'Pull'  -OutputPath $NodeConfigs

#Not Yet Implemented
#DomainController       -ConfigurationData $ConfigData -Role 'PDC'          -OutPath $NodeConfigs
#DomainController       -ConfigurationData $ConfigData -Role 'DC'           -OutPath $NodeConfigs
#FileServer             -ConfigurationData $ConfigData -Role 'FileServer'   -OutPath $NodeConfigs

#Generate DSC Checksum for configs for DSC Pull
New-DSCCheckSum -ConfigurationPath $NodeConfigs -OutPath $NodeConfigs


#-------------------------------------------#
#Generate and Push HyperV/VM Configurations
#-------------------------------------------#

<<<<<<< HEAD
#For Testing pause before each start-dscconfiguration command

HyperVHost     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $HVConfigs
pause
Start-DSCConfiguration -Path $HVConfigs -Force -Wait -Verbose

PullServerVM   -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $HVConfigs
pause
Start-DSCConfiguration -Path $HVConfigs -Force -Wait -Verbose

#This guy is just for testing
PullNodeVM     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $HVConfigs
pause
Start-DSCConfiguration -Path $HVConfigs -Force -Wait -Verbose
=======
#Host Config - Ensure presense of Hyper-V Role
HyperVHost     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $VMConfigs
Start-DSCConfiguration -Path $VMConfigs -Force -Wait -Verbose

#Create the PullServerVM
PullServerVM   -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $VMConfigs
Start-DSCConfiguration -Path $VMConfigs -Force -Wait -Verbose

#This guy is just for testing
PullNodeVM     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $VMConfigs
Start-DSCConfiguration -Path $VMConfigs -Force -Wait -Verbose
>>>>>>> origin/master

