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
$NodeConfigPath  = Join-Path -Path $ResourcePath    -ChildPath "Nodes"
#Path to store xHyperV Configuration files to be executed on the Hyper-V Host, these aren't referenced by any script except this when executing Start-DSCConfiguration
$VMConfigPath    = Join-Path -Path $ResourcePath    -ChildPath "VirtualMachines"

#Clean up the resource path (keep files in the root of directory - delete all subdirs)
Get-ChildItem $ResourcePath | ? Attributes -eq 'Directory' | Remove-Item -Force -Recurse
#Remove-Item $ResourcePath -Force -Recurse

if(-not (Test-Path $ResourcePath)) {
    New-Item -Path $ResourcePath -ItemType Directory -Force
}

New-Item -Path $NodeConfigPath -ItemType Directory -Force
New-Item -Path $VMConfigPath -ItemType Directory -Force

#---------------------------------#
#Config Generation Block
#---------------------------------#
#Do we need to pass $NodeConfigPath to configdata? Don't think so. -No references to it, removing it.

$SplatConfig = @{
    "ResourcePath" = $ResourcePath
    "SourceVHDPath" = "C:\SourceVHD.vhdx"
    "DeploymentPath" = "C:\Deploy\"
    "Verbose" = $True
}

$ConfigData = & "$PSScriptRoot\ConfigurationData.ps1" @SplatConfig

#Mainly for testing - ensure an outdated version of DeploymentConfig isn't loaded
Remove-Module DeploymentConfiguration -ErrorAction Ignore

Import-Module $PSScriptRoot\DeploymentConfiguration.psm1 -Verbose:$False

PullServer    -ConfigurationData $ConfigData -Role 'PullServer'   -OutputPath $ResourcePath\PullServer
PullNode      -ConfigurationData $ConfigData -Role 'PullNode'     -OutputPath $NodeConfigPath
PullNodeLCM   -ConfigurationData $ConfigData -RefreshMode 'Pull'  -OutputPath $NodeConfigPath

#Not Yet Implemented
#DomainController       -ConfigurationData $ConfigData -Role 'PDC'          -OutPath $NodeConfigPath
#DomainController       -ConfigurationData $ConfigData -Role 'DC'           -OutPath $NodeConfigPath
#FileServer             -ConfigurationData $ConfigData -Role 'FileServer'   -OutPath $NodeConfigPath

#Generate DSC Checksum for configs for DSC Pull
New-DSCCheckSum -ConfigurationPath $NodeConfigPath -OutPath $NodeConfigPath

#-------------------------------------------#
#Generate and Push HyperV/VM Configurations
#-------------------------------------------#


#For Testing pause before each start-dscconfiguration command
Write-Host "Starting HV Configs"

#Host Config - Ensure presense of Hyper-V Role
HyperVHost     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $VMConfigPath
#Start-DSCConfiguration -Path $VMConfigPath -Force -Wait -Verbose
pause

#Create the PullServerVM
PullServerVM   -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $VMConfigPath
#Start-DSCConfiguration -Path $VMConfigPath -Force -Wait -Verbose
pause

#This guy is just for testing
PullNodeVM     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $VMConfigPath
#Start-DSCConfiguration -Path $VMConfigPath -Force -Wait -Verbose
pause
