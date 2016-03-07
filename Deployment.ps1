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
     
    List of DSC resources that should be present on the system: (Not current)
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

#REQUIRES -Version 5

#BRANCH MASTER

#---------------------------------#
#Setup and Path/Dir Config
#---------------------------------#

#Sub folder containing any resource files required by the script - e.g. VHDx template files, generated DSC MOF files
$ResourcePath    = Join-Path -Path $PSScriptRoot    -ChildPath "Resources"
#Path to store generated node MOF files, these files are injected into VHDs to perform initial configuration tasks
$NodeConfigPath  = Join-Path -Path $ResourcePath    -ChildPath "Nodes"
#Path for exported DSC Packages (zip files for DSC Pull Server)
$NodeModulePath  = Join-Path -Path $ResourcePath    -ChildPath "Modules"
#Path to store xHyperV Configuration files to be executed on the Hyper-V Host, these aren't referenced by any script except this when executing Start-DSCConfiguration
$VMConfigPath    = Join-Path -Path $ResourcePath    -ChildPath "VirtualMachines"

#Clean up the resource path (keep files in the root of directory - delete all subdirs except Certificates)
Get-ChildItem $ResourcePath | ? {($_.Attributes -eq 'Directory') -and ($_.BaseName -ne 'Certificates')} | Remove-Item -Force -Recurse

if(-not (Test-Path $ResourcePath)) {
    New-Item -Path $ResourcePath -ItemType Directory -Force | Out-Null
}

New-Item -Path $NodeConfigPath -ItemType Directory -Force | Out-Null
New-Item -Path $NodeModulePath -ItemType Directory -Force | Out-Null
New-Item -Path $VMConfigPath -ItemType Directory -Force | Out-Null

#---------------------------------#
#Config Generation Block
#---------------------------------#
$ConfigDataParams = @{
    "ResourcePath"       = $ResourcePath
    "SourceVHDPath"      = "$ResourcePath\SourceVHD.vhdx"
    "DeploymentPath"     = "E:\HyperV\AutoDeploy"
    "PullCertThumbprint" = '12E33D877D27546998AA05056ADB0DDCF31A7763'
    "Verbose" = $False
}

$ConfigData = & "$PSScriptRoot\Configuration\ConfigurationData.ps1" @ConfigDataParams


#Mainly for testing - ensure an outdated version of DeploymentConfig isn't loaded
Remove-Module DeploymentConfiguration -ErrorAction SilentlyContinue | Out-Null

Import-Module $PSScriptRoot\Configuration\DeploymentConfiguration.psm1 -Verbose:$False

PullServer -ConfigurationData $ConfigData -Role 'PullServer'   -OutputPath $ResourcePath\PullServer
PullNode   -ConfigurationData $ConfigData -Role 'PullNode'     -OutputPath $NodeConfigPath
FirstDC    -ConfigurationData $ConfigData -Role 'FirstDC'      -OutputPath $NodeConfigPath
DC         -ConfigurationData $ConfigData -Role 'SDC'          -OutputPath $NodeConfigPath

#Generate LCM for all nodes that will pull a configuration
PullNodeLCM   -ConfigurationData $ConfigData -RefreshMode 'Pull'  -OutputPath $NodeConfigPath
PushNodeLCM   -ConfigurationData $ConfigData -RefreshMode 'Push'  -OutputPath $NodeConfigPath



#FileServer             -ConfigurationData $ConfigData -Role 'FileServer'   -OutPath $NodeConfigPath

#Generate DSC Checksum for configs for DSC Pull
New-DSCCheckSum -ConfigurationPath $NodeConfigPath -OutPath $NodeConfigPath

#-------------------------------------------#
#Generate and Push HyperV/VM Configurations
#-------------------------------------------#

#For Testing pause before each start-dscconfiguration command
Write-Information -MessageData "Pushing Hyper-V Configs"

#Host Config - Ensure presense of Hyper-V Role
HyperVHost     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $VMConfigPath
Start-DSCConfiguration -Path $VMConfigPath -Force -Wait -Verbose:$Verbose

Write-Warning "About to configure Primary DC"
FirstDCVM      -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $VMConfigPath
Start-DscConfiguration -Path $VMConfigPath -Force -Wait -Verbose:$Verbose
#Wait for DC to configure
Write-Warning "Waiting for PDC to configure"
Start-Sleep -Seconds 120

#Testing - Configure secondary domain controller
GuestVM -ConfigurationData $ConfigData -Role 'HyperVHost' -VMName 'SecondDomainController' -OutputPath $VMConfigPath
Start-DscConfiguration -Path $VMConfigPath -Force -Wait -Verbose:$Verbose

#Create the PullServerVM
PullServerVM   -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $VMConfigPath
Start-DSCConfiguration -Path $VMConfigPath -Force -Wait -Verbose:$Verbose

#This guy is just for testing that our pull server works
PullNodeVM     -ConfigurationData $ConfigData -Role 'HyperVHost'   -OutputPath $VMConfigPath
Start-DSCConfiguration -Path $VMConfigPath -Force -Wait -Verbose:$Verbose



