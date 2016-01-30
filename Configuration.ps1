
$scriptLocation = $PSScriptRoot



$ConfigData = & "$scriptlocation\ConfigurationData.ps1"


Configuration VirtualMachine
{
    param (
        [Parameter(Mandatory)]
        [Hashtable]$VMConfig
    )
    Import-DscResource -ModuleName xHyper-V

    xVHD VHD
    {
        ParentPath           = $Node.VHDParentPath
        Name                 = $VMConfig.MachineName
        Path                 = $Node.VHDDestinationPath -f $VMConfig.MachineName
        Generation           = $Node.VHDGeneration
        Ensure               = "Present"
    }
    cVHDFile FileCopy
    {
        PartitionNumber = $Node.VHDPartitionNumber
        VhdPath = $Node.VHDDestinationPath -f $VMConfig.MachineName
        FileDirectory = $VMConfig.VMFileCopy | % {
            MSFT_xFileDirectory {
                SourcePath = $_.source
                DestinationPath = $_.destination
            }
        }
        DependsOn = "[xVHD]VHD"
    }

    xVMHyperV VirtualMachine
    {
        Name                 = $VMConfig.MachineName
        VhDPath              = $Node.VHDDestinationPath -f $VMConfig.MachineName
        SwitchName           = $Node.SwitchName
        State                = $Node.VMState
        StartupMemory        = $VMConfig.MemorySizeVM
        MACAddress           = $VMConfig.MACAddress
        Generation           = $VMConfig.VMGeneration
        DependsOn            = '[cVHDFile]FileCopy'
    }
}

Configuration HyperVHost {
    


}

Configuration PullServerVM {

}

Configuration PullServer {

}


Configuration PullNodeVM {
    param (
        [Parameter(Mandatory)]
        [String]$Role = 'HyperVHost'
    )
    Node $AllNodes.Where{$_.Role -eq $Role}.NodeName {
        VirtualMachine PullNode {
            VMConfig = $Node.DSCPullServer
        }
    }
}

Configuration PullNode {


}


function Get-DscResourceModulePath
{
    param(
        [Parameter(Mandatory)]
        [string] $DscResourceName)

    $dscResource = Get-DscResource $DscResourceName
    $dscResource.Module.ModuleBase
}


PullNodeVM -Role HyperVHost -ConfigurationData $ConfigData -outputpath = C:\Dev\Powershell\DSC\Testing30Jan\