
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
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )

    Import-DSCResource -ModuleName xHyper-V, PSDesiredStateConfiguration

    #Write-Verbose ("Current Invocation: {0}" -f (Split-Path $MyInvocation.MyCommand.Definition))

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

    Import-DscResource -ModuleName xNetworking, xComputerManagement,xPSDesiredStateConfiguration,PSDesiredStateConfiguration

    Node $AllNodes.Where{$_.Role -eq $Role}.NodeName {

        WindowsFeature DSCService {
            Ensure = "Present"
            Name = "DSC-Service"
        }
        xDSCWebService PullServerEP {
            EndpointName        = "DSCPullServer"
            CertificateThumbPrint = $Node.CertificateThumbprint
            ConfigurationPath   = $Node.ConfigurationPath
            Port                = $Node.Port            
            ModulePath          = $Node.ModulePath
            PhysicalPath        = $Node.PhysicalPath
            RegistrationKeyPath = $Node.RegistrationKeyPath
            State               = "Started"
            IsComplianceServer  = $false
            Ensure              = "Present"
            DependsOn           = "[WindowsFeature]DSCService"
        }
        if($Node.StaticIP) {
            xIPAddress PullServerStaticIP {
                IPAddress       = $Node.IPAddress
                SubnetMask      = $Node.SubnetMask
                InterfaceAlias  = "Ethernet*"
                AddressFamily   = $Node.AddressFamily
            }
        } #Else rely on DHCP
        xComputer PullServerName {
            Name          = $Node.MachineName
            WorkGroupName = 'WORKGROUP'
            #DomainName    = $Node.DomainName
            #TODO: Implement credentials for operations
            #Credential    = ''
        }
        LocalConfigurationManager {
            ConfigurationModeFrequencyMins = 30
            ConfigurationMode = "ApplyAndAutoCorrect"
            RefreshMode = "Pull"
            RefreshFrequencyMins = 30
            DownloadManagerName = "WebDownloadManager"
            DownloadManagerCustomData = @{ServerUrl="http://172.16.10.155:8080/psdscpullserver.svc";
                                          AllowUnsecureConnection = 'true'
                                         }
            ConfigurationID = $Node.NodeName
            RebootNodeIfNeeded = $true
            AllowModuleOverwrite = $true
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
    Import-DSCResource -ModuleName xNetworking, xComputerManagement,PSDesiredStateConfiguration
    
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
        LocalConfigurationManager {
            RebootNodeIfNeeded = $True

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
