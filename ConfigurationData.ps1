param (
    #Host DSC Resources
    [Parameter(Mandatory)]
    [String]$ScriptRoot,
    [Parameter(Mandatory)]
    [String]$BaseVHDPath,
    [String]$HyperVHost         = "localhost",
    [string]$NewDomainName      = "dev.rusthawk.net"
)

$DSCxWebService      = (Get-DSCResource -Name xDSCWebService).Module.ModuleBase

##
#ResourcePath - Where any ancilliary resource files will be located for copying to nodes
#NodeConfigs - Subpath of ResourcePath where node .mof files are located
##

#Generate GUIDs for Machines
$PullServerGUID = [guid]::NewGuid()
$PullNodeGUID   = [guid]::NewGuid()
$FirstDomainControllerGUID = [guid]::NewGuid()
$SecondDomainControllerGUID = [guid]::NewGuid()

#This can probably be set in NonNodeData
$PullServerIP   = '172.16.10.150'

@{
    AllNodes = @(
        @{
            NodeName = "*"
        };
        @{
            NodeName                = $PullServerGUID
            MachineName             = 'PullServer'
            Role                    = 'PullServer'
            DomainName              = $NewDomainName
            ModulePath              = "$env:ProgramFiles\WindowsPowerShell\DSCService\Modules"
            ConfigurationPath       = "$env:ProgramFiles\WindowsPowerShell\DSCService\Configuration"
            RegistrationKeyPath     = "$env:ProgramFiles\WindowsPowerShell\DSCService\registration.txt" 
            CertificateThumbprint   = "AllowUnencryptedTraffic"
            PhysicalPath            = "$env:SystemDrive\inetpub\wwwroot\DSCPullServer"
            Port                    = 8080
            State                   = "Started"
            StaticIP                = $True
            IPAddress               = $PullServerIP
            AddressFamily           = 'IPv4'
            SubnetMask              = '24'
            RefreshMode             = 'Push'
        };
        @{
            NodeName                = $PullNodeGUID
            MachineName             = 'PullNode'
            Role                    = 'PullNode'
            DomainName              = $NewDomainName
            StaticIP                = $True
            IPAddress               = '172.16.10.165'
            AddressFamily           = 'IPv4'
            SubnetMask              = '24'
            RefreshMode             = 'Pull'
        };
        @{
            NodeName            = $FirstDomainControllerGUID
            MachineName         = 'FirstDomainController'
            Role                = 'FirstDomainController'
            DomainName          = $NewDomainName
            StaticIP            = $True
            IPAddress           = '172.16.1.21'
            SubnetMask          = '24'
            RefreshMode         = 'Pull'
            
            DomainAdminCreds    = ''
            DomainSafeModePW    = ''
            
        };
        @{
            NodeName            = $SecondDomainControllerGUID
            MachineName         = 'SecondDomainController'
            Role                = 'DomainController'
            DomainName          = $NewDomainName
            StaticIP            = $True
            IPAddress           = '172.16.1.31'
            SubnetMask          = '24'
            RefreshMode         = 'Pull'
            
            
        }
        
        @{
            NodeName            = $HyperVHost
            Role                = "HyperVHost"
            ResourcePath        = "$env:SystemDrive\Hyper-V\DSC\Resources\"
            VHDParentPath       = $ScriptRoot -f "parentvhd.vhdx"
            VHDGeneration       = "VHDX"
            VHDDestinationPath  = "$BaseVHDPath\{0}.vhdx"
            VHDPartitionNUmber  = 4
            SwitchName          = "Red-Hawk Production"
            SwitchType          = "External"
            VMState             = "Running"
            
            DSCPullServer = @{
                MachineName     = "DSCPullServer"
                MemorySizeVM    = 2048MB
                MACAddress      = '00155D8A54A0'
                VMGeneration    = 2
                VMFileCopy      = @(
                    @{
                        Source      = $ScriptRoot -f "$PullServerGUID.mof";
                        Destination = 'Windows\System32\Configuration\pending.mof'
                    }
                    @{
                        Source      = $ScriptRoot -f "$PullServerGUID.meta.mof";
                        Destination = 'Windows\System32\Configuration\metaconfig.mof'
                    }
                    @{
                        Source      = $ScriptRoot -f 'pullserver_unattend.xml';
                        Destination = 'unattend.xml'
                    }
                    @{
                        Source      = $DSCxWebService;
                        Destination = 'Program Files\WindowsPowerShell\Modules\xPSDesiredStateConfiguration'
                    }
                    @{
                        Source      = $ScriptRoot -f 'Deploy\Nodes\*.mof';
                        Destination = 'Program Files\WindowsPowerShell\DSCService\Configuration'                        
                    }
                ) 
            }
            
            DSCPullNode = @{
                MachineName     = "DSCPullNode"
                MemorySizeVM    = 2048MB
                MACAddress      = "00155D8A54A5"
                VMGeneration    = 2
                VMFileCopy      = @(
                    @{
                        Source      = $ScriptRoot -f 'pullnode.meta.mof';
                        Destination = 'Windows\System32\Configuration\metaconfig.mof'
                    }
                    @{
                        Source      = $ScriptRoot -f 'pullnode_unattend.xml';
                        Destination = 'unattend.xml'
                    }
                    @{
                        Source      = $ScriptRoot -f 'startlcm.ps1'
                        Destination = 'Scripts\startlcm.ps1'
                    }
                    @{
                        Source      = $ScriptRoot -f 'setup.cmd'
                        Destination = 'Scripts\setup.cmd'
                    }
                )
            }
            
            FirstDomainController = @{
                MachineName     = "FirstDomainController"
                MemorySizeVM    = 2048MB
                #MACAddress      = "00155D8A54A9"
                VMGeneration    = 2
                VMFileCopy      = @(
                    #Insert metaconfig for Domain Controller
                )
            }
            
            SecondDomainController = @{
                MachineName     = "SecondDomainController"
                MemorySizeVM    = 2048MB
                VMGeneration    = 2
                VMFileCopy      = @(
                    
                    
                )
            }
        }
    );
    NonNodeData = @{
        PullServerAddress = $PullServerIP;
        PullServerPort    = '8080'    
    };
}
