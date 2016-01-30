Configuration VirtualMachine
{
    param (
        [string]$HyperVNode = 'hawkwing.red-hawk.net',
        [string]$BaseVHDPath = 'C:\Basevhd.vhdx',
        [string]$DSCWebPath,
        [parameter(Mandatory)]
        [string]$Role
    )

    Import-DscResource -Module xHyper-V,xPSDesiredStateConfiguration

    $basedir = 'C:\Hyper-V\DSC\{0}'

    $filecopy = @(
                    @{'source'      = $basedir -f 'pullserver.mof';
                      'destination' = 'Windows/System32/Configuration/pending.mof'},
                    @{'source'      = $basedir -f 'unattend.xml';
                      'destination' = 'unattend.xml'},
                    @{'source'      = $DSCWebPath;
                      'destination' = 'Program Files/WindowsPowerShell/Modules/xPSDesiredStateConfiguration'}
                )

    
    Node $AllNodes.Where{$_.Role -eq $Role}.NodeName {}

    Node $HyperVNode
    {
        $VMName = 'DEV-DSCPULL-SRV02'
        $path   = 'C:\Hyper-V\DSC\'

        $vhdpath = $path + "{0}.vhdx"

        xVHD VHD
        {
            ParentPath           = $BaseVHDPath
            Name                 = $VMName
            Path                 = $path
            Generation           = 'Vhdx'
            #MaximumSizeBytes     = 20GB
            Ensure               = 'Present'
        }
        cVHDFile FileCopy
        {
            PartitionNumber = 4  
            VhdPath = $vhdpath -f $VMName
            FileDirectory = $filecopy | % {
                MSFT_xFileDirectory {
                    SourcePath = $_.source
                    DestinationPath = $_.destination
                }
            }
            DependsOn = "[xVHD]VHD"
        }

 
        xVMHyperV VirtualMachine
        {
            Name                 = $VMName
            VhDPath              = $vhdpath -f $VMName
            SwitchName           = "Red-Hawk Production"
            State                = "Off"
            StartupMemory        = 2048MB
            MACAddress           = "00155D8A54A0" 
            Generation           = 2
            DependsOn            = '[cVHDFile]FileCopy'
        }
    }
}

function Get-DscResourceModulePath
{
    param(
        [Parameter(Mandatory)]
        [string] $DscResourceName)

    $dscResource = Get-DscResource $DscResourceName
    $dscResource.Module.ModuleBase
}


VirtualMachine -DSCWebPath (Get-DscResourceModulePath 'xDSCWebService')

#"$ConfigDataLocation\VMData\unattend.xml";
#$ConfigDataLocation = Split-Path $MyInvocation.MyCommand.Definition;