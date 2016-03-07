<#
    .PARAMETER ResourcePath
    Define the path to the resource folder where files reside for copying to VMs/VHDs

    .PARAMETER SourceVHDPath
    Path to the Server2012 sysprepped VHDX file that will be used as the base differencing VHD

    .PARAMETER DeploymentPath
    Path to the storage destination for VM files and VHDs

    .PARAMETER NodeChildPath
    Specify an alternate path for generated Node configurations, required for copy operations to the DSC Pull Server.
    Default: Nodes

    .PARAMETER ComputerName
    The Hyper-V Host computer to execute this configuration on
    Alias: HyperVHost for Compatability

    .PARAMETER NewDomainName
    Specify the name of the new domain to provision

    .PARAMETER CredPath
    (Optional) Specify a different path to import/store Credential .clixml files.
    Default: $ResourcePath

    .PARAMETER HTTPSCertThumbprint
    Specify the Certificate Thumbprint of the certificate used to encrypt traffic between the DSC Pull Server and Nodes (HTTPS)
    Default: AllowUnencryptedTraffic

    .PARAMETER MOFCertThumbprint
    Thumbprint of the certificate used to encrypt/decrypt MOF file credentials

    .PARAMETER MOFCertPath
    Path to the certificate public key (.cer) used to encrypt MOF file credentials

#>

param (
    #Host DSC Resources
    [Parameter(Mandatory)]
    [string]$ResourcePath,
    [Parameter(Mandatory)]
    [string]$SourceVHDPath,
    [Parameter(Mandatory)]
    [String]$DeploymentPath,
    [String]$NodeChildPath      = "Nodes",
    [Alias("HyperVHost")]
    [String]$ComputerName       = "localhost",
    [string]$NewDomainName      = "dev.rusthawk.net",
    [String]$CredPath           = $ResourcePath,
    [Alias("PullCertThumbprint")]
    [string]$HTTPSCertThumbprint = "AllowUnencryptedTraffic",
    [string]$HTTPSCertPath,
    [string]$MOFCertThumbprint,
    [string]$MOFCertPath
    #[switch]$Verbose
)

Import-Module $PSScriptRoot/../DeploymentHelper.psm1 -Verbose -Force

$DSCResources     = Get-DscResource

$xComputer        = Select-ModuleBase -ResourceInfo $DSCResources -Name 'xComputer'
$xNetworking      = Select-ModuleBase -ResourceInfo $DSCResources -Module 'xNetworking'
$xWebAdmin        = Select-ModuleBase -ResourceInfo $DSCResources -Module 'xWebAdministration'
$xCertificate     = Select-ModuleBase -ResourceInfo $DSCResources -Module 'xCertificate'

##
#ResourcePath - Where any ancilliary resource files will be located for copying to nodes
#SourceVHDPath - The source VHD(x) file to generate VM's from
#DeploymentPath - Where we will be storing VM's and VHD files on the Hyper-V Host
##

#For ease of use using string formatting -f
$ResourcePath += "\{0}"

$BaseVHDPath = $ResourcePath -f 'basevhd.vhdx'

#Designate a Prefix for the name of the Hyper-V VMs
$VMPrefix = "DEV-DSC-"

$GUID = @{
    'PullServer' = New-MachineName -Name 'PullServer' -Verbose:$Verbose
    'PullNode'   = New-MachineName -Name 'PullNode'   -Verbose:$Verbose
    'FirstDC'    = New-MachineName -Name 'FirstDC'    -Verbose:$Verbose
    'SecondDC'   = New-MachineName -Name 'SecondDC'   -Verbose:$Verbose
}

$IP = @{
    PullServer = '192.168.10.200'
    PullNode   = '192.168.10.100'
    FirstDC    = '192.168.10.21'
    SecondDC   = '192.168.10.31'
}

@{
    AllNodes = @(
        @{
            NodeName = "*"
            CertificateFile = $MOFCertPath            
            Thumbprint      = $MOFCertThumbprint
            PSDscAllowPlainTextPassword = [bool](-not $MOFCertThumbprint -or (-not (Test-Path $MOFCertPath)))
        };
        @{
            NodeName                = $GUID.PullServer
            MachineName             = 'RHPullServer'
            Role                    = 'PullServer'
            DomainName              = $NewDomainName
            ModulePath              = "$env:ProgramFiles\WindowsPowerShell\DSCService\Modules"
            ConfigurationPath       = "$env:ProgramFiles\WindowsPowerShell\DSCService\Configuration"
            RegistrationKeyPath     = "$env:ProgramFiles\WindowsPowerShell\DSCService\registration.txt" 
            
            CertificateCredential   = Import-Credential -Name 'PullServerHTTPS' -Path $CredPath -Export
            CertificatePath         = $HTTPSCertPath
            CertificateThumbprint   = $HTTPSCertThumbprint
            
            PhysicalPath            = "$env:SystemDrive\inetpub\wwwroot\DSCPullServer"
            Port                    = 8080
            State                   = "Started"
            StaticIP                = $True
            IPAddress               = $IP.PullServer
            AddressFamily           = 'IPv4'
            SubnetMask              = '24'
            RefreshMode             = 'Push'
        };
        @{
            NodeName                = $GUID.PullNode
            MachineName             = 'RHPullNode'
            Role                    = 'PullNode'
            DomainName              = $NewDomainName
            AdminCredential         = Import-Credential -Name 'PullAdmin' -Path $CredPath -Export
            StaticIP                = $True
            IPAddress               = $IP.PullNode
            AddressFamily           = 'IPv4'
            SubnetMask              = '24'
            RefreshMode             = 'Pull'
        };
        @{
            NodeName            = $GUID.FirstDC
            MachineName         = 'RH-PDC'
            Role                = 'FirstDC'
            DomainName          = $NewDomainName
            StaticIP            = $True
            IPAddress           = $IP.FirstDC
            AddressFamily       = 'IPv4'
            SubnetMask          = '24'
            RefreshMode         = 'Push'
            #Testing - Function imports clixml creds, if they don't exist will prompt with Get-Cred
            DomainAdminCreds    = Import-Credential -Name 'Administrator' -Path $CredPath -Export
            DomainSafeModePW    = Import-Credential -Name 'DOMSafeModePW' -Path $CredPath -Export
        };
        @{
            NodeName            = $GUID.SecondDC
            MachineName         = 'RH-SDC01'
            Role                = 'SDC'
            DomainName          = $NewDomainName
            StaticIP            = $True
            IPAddress           = $IP.SecondDC
            AddressFamily       = 'IPv4'
            SubnetMask          = '24'
            RefreshMode         = 'Push'
            DomainAdminCreds    = Import-Credential -Name 'Administrator' -Path $CredPath -Export
            DomainSafeModePW    = Import-Credential -Name 'DOMSafeModePW' -Path $CredPath -Export
        };
        #HYPER-V Host and VM ConfigData
        @{
            NodeName            = $ComputerName
            Role                = "HyperVHost"
            ResourcePath        = $ResourcePath
            VHDParentPath       = $BaseVHDPath
            VHDGeneration       = "VHDX"
            VHDDestinationPath  = "$DeploymentPath"
            VHDPartitionNUmber  = 4
            SwitchName          = "Red-Hawk Production"
            SwitchType          = "External"
            NetAdapterName      = "Port 2 - Red-Hawk.net (810)"
            VMState             = "Running"
            Path                = $DeploymentPath

            DSCPullServer = @{
                MachineName     = "$($VMPrefix)DSCPullServer"
                MemorySizeVM    = 2048MB
                #MACAddress      = '00155D8A54A0'
                VMGeneration    = 2
                CPUCount        = 2
                VMFileCopy      = @(
                    @{
                        Source      = $ResourcePath -f "PullServer\$($GUID.PullServer).mof";
                        Destination = 'Windows\System32\Configuration\pending.mof'
                    }
                    @{
                        Source      = $ResourcePath -f "PullServer\$($GUID.PullServer).meta.mof";
                        Destination = 'Windows\System32\Configuration\metaconfig.mof'
                    }
                    @{
                        Source      = $ResourcePath -f 'pullserver_unattend.xml';
                        Destination = 'unattend.xml'
                    }
                    @{
                        #Copy all node mof files to pull server
                        Source      = $ResourcePath -f "$NodeChildPath\*.mof";
                        Destination = 'Program Files\WindowsPowerShell\DSCService\Configuration'                        
                    }
                    @{
                        #Copy all node mof checksums to pull server
                        Source      = $ResourcePath -f "$NodeChildPath\*.mof.checksum";
                        Destination = 'Program Files\WindowsPowerShell\DSCService\Configuration'                        
                    }
                    @{
                        Source      = $ResourcePath -f 'Certificates\PSDSCPullServer.pfx';
                        Destination = 'Scripts\PSDSCPullServer.pfx'
                    }
                    @{
                        Source      = Select-ModuleBase -ResourceInfo $DSCResources -Name 'xDSCWebService';
                        Destination = 'Program Files\WindowsPowerShell\Modules\xPSDesiredStateConfiguration'
                    }
                    @{
                        Source      = $xWebAdmin;
                        Destination = 'Program Files\WindowsPowerShell\Modules\xWebAdministration'
                    }
                    @{
                        Source      = $xCertificate;
                        Destination = 'Program Files\WindowsPowerShell\Modules\xCertificate'
                    }
                    @{
                        Source      = Export-DSCModule -ModuleName 'xActiveDirectory' -ExportPath ($ResourcePath -f "Modules") -PassThru;
                        Destination = 'Program Files\WindowsPowerShell\DSCService\Modules'
                    }
                ) 
            }
            
            DSCPullNode = @{
                MachineName     = "$($VMPrefix)DSCPullNode"
                MemorySizeVM    = 2048MB
                #MACAddress      = "00155D8A54A5"
                VMGeneration    = 2
                CPUCount        = 2
                VMFileCopy      = @(
                    @{
                        Source      = $ResourcePath -f "$NodeChildPath\$($GUID.PullNode).meta.mof";
                        Destination = 'Windows\System32\Configuration\metaconfig.mof'
                    }
                    @{
                        Source      = $ResourcePath -f 'pullnode_unattend.xml';
                        Destination = 'unattend.xml'
                    }
                )
            }
            
            FirstDomainController = @{
                MachineName     = "$($VMPrefix)FirstDomainController"
                MemorySizeVM    = 2048MB
                #MACAddress      = "00155D8A54A9"
                VMGeneration    = 2
                CPUCount        = 2
                VMFileCopy      = @(
                    @{
                        Source      = $ResourcePath -f "$NodeChildPath\$($GUID.FirstDC).meta.mof";
                        Destination = 'Windows\System32\Configuration\metaconfig.mof'
                    }
                    @{
                        Source      = $ResourcePath -f "$NodeChildPath\$($GUID.FirstDC).mof";
                        Destination = 'Windows\System32\Configuration\pending.mof'
                    }
                    @{
                        Source      = $ResourcePath -f 'pullnode_unattend.xml';
                        Destination = 'unattend.xml'
                    }
                    @{
                        Source      = Select-ModuleBase -ResourceInfo $DSCResources -Module 'xActiveDirectory';
                        Destination = 'Program Files\WindowsPowerShell\Modules\xActiveDirectory'
                    }
                    @{
                        Source      = Select-ModuleBase -ResourceInfo $DSCResources -Module 'xDHCPServer';
                        Destination = 'Program Files\WindowsPowerShell\Modules\xDHCPServer'
                    }
                )
            }
            
            SecondDomainController = @{
                MachineName     = "$($VMPrefix)SecondDomainController"
                MemorySizeVM    = 2048MB
                VMGeneration    = 2
                VMFileCopy      = @(
                     @{
                        Source      = $ResourcePath -f "$NodeChildPath\$($GUID.SecondDC).meta.mof";
                        Destination = 'Windows\System32\Configuration\metaconfig.mof'
                    }
                    @{
                        Source      = $ResourcePath -f "$NodeChildPath\$($GUID.SecondDC).mof";
                        Destination = 'Windows\System32\Configuration\pending.mof'
                    }
                    @{
                        Source      = $ResourcePath -f 'pullnode_unattend.xml';
                        Destination = 'unattend.xml'
                    }
                    @{
                        Source      = Select-ModuleBase -ResourceInfo $DSCResources -Module 'xActiveDirectory';
                        Destination = 'Program Files\WindowsPowerShell\Modules\xActiveDirectory'
                    }
                )
            }
        }
    );
    NonNodeData = @{
        PullServerAddress = $IP.PullServer
        PullServerPort = 8080
        SubnetStart = '192.168.10.10'
        SubnetEnd   = '192.168.10.254'
        SubnetMask      = '255.255.255.0'

        DNSServers = @($IP.FirstDC, $IP.SecondDC)
        CommonFiles = @(
            @{
                Source      = $xComputer
                Destination = 'Program Files\WindowsPowerShell\Modules\xComputerManagement'
            }
            @{
                Source      = $xNetworking
                Destination = 'Program Files\WindowsPowerShell\Modules\xNetworking'
            }
            @{
                Source      = $ResourcePath -f 'nodesetup.ps1';
                Destination = 'Scripts\nodesetup.ps1'
            }
            @{
                Source      = $ResourcePath -f 'setup.cmd';
                Destination = 'Scripts\setup.cmd'
            }
            @{
                Source      = $ResourcePath -f 'setup.cmd';
                Destination = 'Windows\Setup\Scripts\SetupComplete.cmd'
            }
            @{
                Source      = $ResourcePath -f 'Certificates\rusthawk-root-ca_RUSTHAWK-ROOT-CA.crt'
                Destination = 'Scripts\rootcert.crt'
            }
        )
        DHCPReservations = @(
            @{
                Name = ''
                MAC  = ''
                IP   = ''
            };        
        )
    }
   
}
