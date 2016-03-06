#Resolve the module path for a specified DSCResourceModule
function Get-DscResourceModulePath
{
    param(
        [Parameter(Mandatory)]
        [string] $DscResourceName)

    $dscResource = Get-DscResource $DscResourceName
    $dscResource.Module.ModuleBase
}

#Generator for Hyper-V Virtual Machines on a Hyper-V Host
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
        Path                 = $Node.VHDDestinationPath
        Generation           = $Node.VHDGeneration
        Ensure               = "Present"
    }

    $AllFiles = $VMConfig.VMFileCopy + $ConfigurationData.NonNodeData.CommonFiles
    $VHDPath  = "$($Node.VHDDestinationPath)\$($VMConfig.MachineName).$($Node.VHDGeneration)"
    cVHDFile FileCopy
    {
        PartitionNumber = $Node.VHDPartitionNumber
        VhdPath = $VHDPath
        FileDirectory = $AllFiles | Foreach-Object {
            MSFT_xFileDirectory {
                SourcePath = $_.Source
                DestinationPath = $_.Destination
            }
        }
        DependsOn = "[xVHD]VHD"
    }

    xVMHyperV VirtualMachine
    {
        Name                 = $VMConfig.MachineName
        Path                 = $Node.Path
        VhDPath              = $VHDPath
        SwitchName           = $Node.SwitchName
        State                = $Node.VMState
        StartupMemory        = $VMConfig.MemorySizeVM
        MACAddress           = $VMConfig.MACAddress
        Generation           = $VMConfig.VMGeneration
        DependsOn            = '[cVHDFile]FileCopy'
        ProcessorCount       = $VMConfig.CPUCount
    }
}

#Configure Hypervisor Server with basic requirements
Configuration HyperVHost {
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )

    Import-DSCResource -ModuleName xHyper-V, PSDesiredStateConfiguration

    Node $AllNodes.Where({$_.Role -eq $Role}).NodeName {
        WindowsFeature HyperV {
            Ensure = "Present"
            Name = "Hyper-V"
        }
        File DeploymentPath {
            DestinationPath = $Node.Path
            Ensure          = "Present"
            Force           = $true
            Type            = "Directory"
        }
        xVMSwitch DeploySwitch {
            Name           = $Node.SwitchName
            Type           = $Node.SwitchType
            NetAdapterName = $Node.NetAdapterName
            Ensure         = "Present"
            DependsOn      = "[WindowsFeature]HyperV"
        }
    }
}

##########################
#Start VM Configurations
##########################

<#
    .SYNOPSIS
    Generate a Hyper-V Guest VM Configuration

    .PARAMETER ConfigName
    (Optional) Specify a Configuration Block name different than the VMName
#>
Configuration HyperVGuest {
    param (
        [Parameter(Mandatory)]
        [String]$Role = "HyperVHos",
        [Parameter(Mandatory)]
        [String]$VMName,
        [String]$ConfigName = $VMName
    )
    
    #Role is always HyperV - selects the HyperV Host node
    #Virtual machines are pulled from 
    Node $AllNodes.Where({$_.Role -eq $Role}).NodeName {
        #Select Machine parameters by $VMName
        VirtualMachine $VMName {
            VMConfig = $Node.$ConfigName
        }
    }
    #e.g. replacing PullServerVM
    #HyperVGuest -Role HyperV -VMName DSCPullServer
}

Configuration PullServerVM {
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )
    Node $AllNodes.Where({$_.Role -eq $Role}).NodeName {
        VirtualMachine PullServer {
            VMConfig = $Node.DSCPullServer
        }
    }
}

Configuration PullNodeVM {
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )
    Node $AllNodes.Where({$_.Role -eq $Role}).NodeName {
        VirtualMachine PullNode {
            VMConfig = $Node.DSCPullNode
        }
    }
}

Configuration FirstDCVM {
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )
    #Role will always be HyperV in this case - evaluate streamlining this
    Node $AllNodes.Where({$_.Role -eq $Role}).NodeName {
        VirtualMachine PullServer {
            VMConfig = $Node.FirstDomainController
        }
    }
}

##########################
#Start guest configurations
##########################

Configuration PullServer {
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )

    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName xCertificate

    Node $AllNodes.Where({$_.Role -eq 'PullServer'}).NodeName {

        WindowsFeature DSCService {
            Ensure = "Present"
            Name = "DSC-Service"
        }
        <#
        xPfxImport DSCServerCert {
            Path = ''
            Thumbprint = '12E33D877D27546998AA05056ADB0DDCF31A7763'
            Credential = $Node.CertificateCredential
            Location   = 'LocalMachine'
            Store      = 'My'
            Exportable = $false

        }#>
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
                InterfaceAlias  = "Ethernet"
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
        xWebsite DefaultIISSite {
            #Ensure the default website is removed from IIS
            Name         = 'Default Web Site'
            PhysicalPath = "$env:Systemroot\inetpub\wwwroot"
            State        = "Stopped"
            Ensure       = "Absent"
            DependsOn    = "[xDSCWebService]PullServerEP"
        }
        LocalConfigurationManager {
            ConfigurationModeFrequencyMins = 30
            ConfigurationMode = "ApplyAndAutoCorrect"
            #Thumbprint of certificate used for MOF encryption
            CertificateID = $Node.Thumbprint
            RebootNodeIfNeeded = $true
            AllowModuleOverwrite = $true
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
    
    Node $AllNodes.Where({$_.Role -eq $Role}).NodeName {
        WindowsFeature TestFeature {
            Ensure = "Present"
            Name = "DNS"
        }
        xComputer SetNodeName {
            Name = $Node.MachineName
            WorkGroupName = 'WORKGROUP'
            #No need to include domain join here
        }
        User Admin {
            UserName = 'Administrator'
            Disabled = $false
            Ensure   = "Present"
            #Password = Get-Credential -Message "PullNode Admin" -UserName "Administrator"
            Password = $Node.AdminCredential
        }
    }
}

#Configuration for the domains initial domain controller
Configuration FirstDC {
    param (
        [Parameter(Mandatory)]
        [String]$Role
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion '2.9.0.0'

    Node $AllNodes.Where({$_.Role -eq $Role}).NodeName {
        WindowsFeature DNSRole {
            Ensure = "Present"
            Name = "DNS"
            IncludeAllSubFeature = $true
        }
        WindowsFeature ADDSRole {
            Ensure = "Present"
            Name = "AD-Domain-Services"
            IncludeAllSubFeature = $true
            #DependsOn = "[WindowsFeature]DNSRole"
        }
        #Create the local user that will become the first domain administrator
        User DomainAdminUser {
            #UserName = $Node.DomainCreds.Username
            UserName = "Administrator"
            Password = $Node.DomainAdminCreds
            Ensure = "Present"
        }
        xADDomain FirstDomain {
            DomainName = $Node.DomainName
            #Credential to check for existance of domain
            DomainAdministratorCredential = $Node.DomainAdminCreds
            SafeModeAdministratorPassword = $Node.DomainSafeModePW
            ParentDomainName = ''
            DependsOn = "[WindowsFeature]ADDSRole"
        }
        xComputer RenameComputer {


        }
    }
}

#Generate LCM Settings to pull configuration for all nodes where RefreshMode is set to $RefreshMode
Configuration PullNodeLCM  {
    param (
        [Parameter(Mandatory)]
        [String]$RefreshMode
    )
    
    $NND = $ConfigurationData.NonNodeData

    Node $AllNodes.Where({$_.RefreshMode -eq $RefreshMode}).NodeName {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $True
            RefreshMode = "Pull"
            CertificateID = $Node.Thumbprint
            ConfigurationID = $Node.NodeName
            
            RefreshFrequencyMins = 30
            DownloadManagerName = "WebDownloadManager"
            #Add variable or dns name property for pull server
            DownloadManagerCustomData = @{ServerUrl="http://$($ConfigurationData.NonNodeData.PullServerAddress)`:$($ConfigurationData.NonNodeData.PullServerPort)/psdscpullserver.svc";
                                            AllowUnsecureConnection = 'true'
                                            }
        }
    }
}
