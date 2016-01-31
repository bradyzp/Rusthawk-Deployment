param (
    #Host DSC Resources
    [String]$DSCResourcePath    = "C:\Hyper-V\DSC\Resources\{0}"  
    [String]$HyperVHost         = "localhost"
    [string]$NewDomainName      = "dev.rusthawk.net"
)

$DSCxWebService      = (Get-DSCResource -Name xDSCWebService).Module.ModuleBase

#Generate GUIDs for Machines
$PullServerGUID = [guid]::NewGuid()
$PullNodeGUID   = [guid]::NewGuid()

@{
    AllNodes = @(
        @{
            NodeName = "*"
        };
        @{
            #This will be injected into the VHD - so target localhost
            #Test this - assign GUID for use by pull config - see if machine still configures when inserted to pending.mof
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
            IPAddress               = '172.16.10.155'
            AddressFamily           = 'IPv4'
            SubnetMask              = '24'
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
        };
        @{
            NodeName            = $HyperVHost
            Role                = "HyperVHost"
            ResourcePath        = "$env:SystemDrive\Hyper-V\DSC\Resources\"
            VHDParentPath       = $DSCResourcePath -f "parentvhd.vhdx"
            VHDGeneration       = "VHDX"
            VHDDestinationPath  = "C:\Hyper-V\DSC\{0}.vhdx"
            VHDPartitionNUmber  = 4
            SwitchName          = "Red-Hawk Production"
            VMState             = "Running"
            
            DSCPullServer = @{
                MachineName     = "DSCPullServer"
                MemorySizeVM    = 2048MB
                MACAddress      = '00155D8A54A0'
                VMGeneration    = 2
                VMFileCopy      = @(
                    @{
                        Source      = $DSCResourcePath -f 'pullserver.mof';
                        Destination = 'Windows\System32\Configuration\pending.mof'
                    }
                    @{
                        Source      = $DSCResourcePath -f 'pullserver_unattend.xml';
                        Destination = 'unattend.xml'
                    }
                    @{
                        Source      = $DSCxWebService;
                        Destination = 'Program Files\WindowsPowerShell\Modules\xPSDesiredStateConfiguration'
                    }
                    @{
                        #Copy any generated node configurations - fix pathing
                        Source      = $DSCResourcePath -f 'NodeConfig\';
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
                        Source      = $DSCResourcePath -f 'pullnode.meta.mof';
                        Destination = 'Windows\System32\Configuration\metaconfig.mof'
                    }
                    @{
                        Source      = $DSCResourcePath -f 'pullnode_unattend.xml';
                        Destination = 'unattend.xml'
                    }
                )
            }
            
            FirstDomainController = @{
                MachineName     = "FirstDomainController"
                MemorySizeVM    = 2048MB
                MACAddress      = "00155D8A54A9"
                VMGeneration    = 2
                VMFileCopy      = @(
                    #Insert metaconfig for Domain Controller
                )
            }
            
            
            
            
        }
    );
    #Not sure if this will be necesarry or not
    GUIDS = @{
        'PullNode'  = $PullNodeGUID
        
    }
        
        
}