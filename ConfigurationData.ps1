$DSCResourcePath     = "C:\Hyper-V\DSC\Resources\{0}"
$DSCxWebService      = (Get-DSCResource -Name xDSCWebService).Module.ModuleBase

@{
    AllNodes = @(
        @{
            NodeName = "*"
        };
        @{
            NodeName        = 'Placeholder'
            MachineName     = 'PullServer'
            Role            = 'PullServer'
            DomainName      = 'dev.rusthawk.net'
            ModulePath      = "$env:ProgramFiles\WindowsPowerShell\DSCService\Modules"
            ConfigurationPath = "$env:ProgramFiles\WindowsPowerShell\DSCService\Configuration"
            RegistrationKeyPath = "$env:ProgramFiles\WindowsPowerShell\DSCService\registration.txt" 
            
        
        };
        @{
            NodeName            = "localhost"
            Role                = "HyperVHost"
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
            
            
            
            
        }
        




    )
}