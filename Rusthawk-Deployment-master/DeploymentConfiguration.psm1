
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
    param (
        [Parameter(Mandatory)]
        [String]$Role,
        [String]$ResourceCopy
    )

    Import-DSCResource -ModuleName xHyper-V

    Node $AllNodes.Where{$_.Role -eq $Role}.NodeName {
        WindowsFeature HyperV {
            Ensure = "Present"
            Name = "Hyper-V"
        }
        xVMSwitch DeploySwitch {
            Name = $Node.SwitchName
            Type = $Node.SwitchType
            Ensure = "Present"
            DependsOn = "[WindowsFeature]HyperV"
        }
        if($ResourceCopy) {
        #Copy resources required for target nodes from the DSC initiator to the Hyper-V Host
            File ResourceCopy {
                DestinationPath = $Node.ResourcePath
                SourcePath = $ResourceCopy
                Recurse = $true
                Type = "Directory"
                Checksum = "SHA-256"
            }
        }
    }
}

Configuration PullServerVM {
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )
    Node $AllNodes.Where{$_.Role -eq $Role}.NodeName {
        VirtualMachine PullServer {
            VMConfig = $Node.DSCPullServer
        }
    }
}

Configuration PullServer {
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration,xNetworking,xComputerManagement

    Node $AllNodes.Where{$_.Role -eq $Role}.NodeName {

        WindowsFeature DSCService {
            Ensure = "Present"
            Name = "DSC-Service"
        }
        xDSCWebService PullServer {
            EndpointName        = "DSCPullServer"
            CertificateThumbPrint = $Node.CertificateThumbprint
            ConfigurationPath   = $Node.ConfigurationPath
            Port                = $Node.Port            
            ModulePath          = $Node.ModulePath
            PhysicalPath        = $Node.PhysicalPath
            RegistrationKeyPath = $Node.RegistrationKeyPath
            State               = $Node.State
            IsComplianceServer  = $false
            Ensure              = "Present"
            DependsOn           = "[WindowsFeature]DSCService"
        }
        if($Node.StaticIP) {
            xIPAddress PullServerStaticIP {
                IPAddress       = $Node.IPAddress
                SubnetMask      = $Node.SubnetMask
                InterfaceAlias  = "*Ethernet*"
                AddressFamily   = $Node.AddressFamily
            }
        } #Else rely on DHCP
        xComputer PullServerName {
            Name          = $Node.MachineName
            WorkGroupName = 'WORKGROUP'
            DomainName    = $Node.DomainName
            #TODO: Implement credentials for operations
            Credential    = ''
        }
    }
}

Configuration PullNodeVM {
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )
    Node $AllNodes.Where{$_.Role -eq $Role}.NodeName {
        VirtualMachine PullNode {
            VMConfig = $Node.DSCPullServer
        }
    }
}

Configuration PullNode {
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )
    
    #We will just be creating a sample configuration for testing Pull config
    Import-DSCResource xNetworking,xComputerManagement
    
    Node $AllNodes.Where{$_.Role -eq $Role}.NodeName {
        WindowsFeature TestFeature {
            Ensure = "Present"
            Name = "DNS"
        }
        xComputer SetNodeName {
            Name = $Node.MachineName
            WorkGroupName = 'WORKGROUP'
            #No need to include domain join here    
        }
        User DisableAdmin {
            UserName = 'Administrator'
            Disabled = $True
            Ensure = "Present"
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
