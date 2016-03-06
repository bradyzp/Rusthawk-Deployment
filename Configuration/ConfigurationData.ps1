<#
    .PARAMETER ResourcePath

    .PARAMETER SourceVHDPath

    .PARAMETER DeploymentPath

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
    [String]$ComputerName       = "localhost",           #Change to ComputerName?
    [string]$NewDomainName      = "dev.rusthawk.net",
    [String]$CredPath           = $ResourcePath,
    [Alias("PullCertThumbprint")]
    [string]$HTTPSCertThumbprint = "AllowUnencryptedTraffic"
)

Import-Module $PSScriptRoot/../DeploymentHelper.psm1 -Verbose

$DSCResources     = Get-DscResource

$xWebService      = Select-ModuleBase -ResourceInfo $DSCResources -Name 'xDSCWebService'
$xComputer        = Select-ModuleBase -ResourceInfo $DSCResources -Name 'xComputer'
$xNetworking      = Select-ModuleBase -ResourceInfo $DSCResources -Module 'xNetworking'
$xWebAdmin        = Select-ModuleBase -ResourceInfo $DSCResources -Module 'xWebAdministration'
$xCertificate     = Select-ModuleBase -ResourceInfo $DSCResources -Module 'xCertificate'

$PullServerIP   = '172.16.10.150'  #This might become a parameter

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

#####
#GUID GENERATION BLOCK
#####
$PullServerGUID             = ([guid]::NewGuid()).guid
$PullNodeGUID               = ([guid]::NewGuid()).guid
$FirstDomainControllerGUID  = ([guid]::NewGuid()).guid
$SecondDomainControllerGUID = ([guid]::NewGuid()).guid

#$Script = Split-Path $MyInvocation.MyCommand.Path -Leaf
#Write-Verbose -Message "[$Script]: PullServerGUID: $PullServerGUID"
#Write-Verbose -Message "[$Script]: PullNodeGUID: $PullNodeGUID"
#Write-Verbose -Message "[$Script]: FDCGUID: $FirstDomainControllerGUID"
#Write-Verbose -Message "[$Script]: SDCGUID: $SecondDomainControllerGUID"




#Generate selfsigned certificate to encrypt MOF Credentials
#-Certificate is generated on the Host (Hyper-V)
#Private key is exported to pfx file (protected by -PrivateKeyCred credential) to be copied to the node
#Private key pfx needs to be imported on the node (Import-PFXCertificate) to enable decryption of MOF files encrypted using the pub key on the Hyper-V Host
#Figure out how to import the pfx as it requires a password, how to do this safely?

#MOF Encryption Certificate Thumbprint
#$Thumbprint = New-DSCCertificate -CertName "MOFCert" -OutputPath ($ResourcePath -f '') -PrivateKeyCred (Import-Clixml -Path ($CredPath -f 'MOFCertCred.clixml'))
$MOFThumbprint = 'DDB954208A637355450667FADA84A35B47941C78'

@{
    AllNodes = @(
        @{
            NodeName = "*"
            #CertificateFile = $ResourcePath -f "Certificates\DSCMOFEncryptionPublicKey.cer"
            #Thumbprint      = $MOFThumbprint
            PSDscAllowPlainTextPassword = $true
        };
        @{
            NodeName                = $PullServerGUID
            MachineName             = 'RHPullServer'
            Role                    = 'PullServer'
            DomainName              = $NewDomainName
            ModulePath              = "$env:ProgramFiles\WindowsPowerShell\DSCService\Modules"
            ConfigurationPath       = "$env:ProgramFiles\WindowsPowerShell\DSCService\Configuration"
            RegistrationKeyPath     = "$env:ProgramFiles\WindowsPowerShell\DSCService\registration.txt" 
            
            CertificateThumbprint   = $HTTPSCertThumbprint
            #PSCredential used to import the PFX Certificate (password)
            #CertificateCredential   = Import-Clixml ($CredPath -f 'PSDSCCertCred.clixml')
            #HTTPS Certificate to encrypt DSC Server Communications
            CertificatePath         = $ResourcePath -f 'Certificates\PSDSCPullServerCert.pfx'
            
            PhysicalPath            = "$env:SystemDrive\inetpub\wwwroot\DSCPullServer"
            Port                    = 8080
            State                   = "Started"
            StaticIP                = $True
            IPAddress               = $PullServerIP
            AddressFamily           = 'IPv4'
            SubnetMask              = '24'
            RefreshMode             = 'Push'
        }
        @{
            NodeName                = $PullNodeGUID
            MachineName             = 'RHPullNode'
            Role                    = 'PullNode'
            DomainName              = $NewDomainName
            AdminCredential         = Import-Credential -Name 'PullAdmin' -Path $CredPath -Export
            StaticIP                = $True
            IPAddress               = '172.16.10.165'
            AddressFamily           = 'IPv4'
            SubnetMask              = '24'
            RefreshMode             = 'Pull'
        };
        @{
            NodeName            = $FirstDomainControllerGUID
            MachineName         = 'FirstDomainController'
            Role                = 'FirstDC'
            DomainName          = $NewDomainName
            StaticIP            = $True
            IPAddress           = '172.16.10.221'
            SubnetMask          = '24'
            RefreshMode         = 'Pull'
            #Testing - Function imports clixml creds, if they don't exist will prompt with Get-Cred
            DomainAdminCreds    = Import-Credential -Name 'Administrator' -Path $CredPath -Export
            DomainSafeModePW    = Import-Credential -Name 'DOMSafeModePW' -Path $CredPath -Export
        };
        @{
            NodeName            = $SecondDomainControllerGUID
            MachineName         = 'SecondDomainController'
            Role                = 'DomainController'
            DomainName          = $NewDomainName
            StaticIP            = $True
            IPAddress           = '192.168.10.31'
            SubnetMask          = '24'
            RefreshMode         = 'Pull'
            
            DomainAdminCreds    = Import-Credential -Name 'Administrator' -Path $CredPath -Export
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
                        Source      = $ResourcePath -f "PullServer\$PullServerGUID.mof";
                        Destination = 'Windows\System32\Configuration\pending.mof'
                    }
                    @{
                        Source      = $ResourcePath -f "PullServer\$PullServerGUID.meta.mof";
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
                        Source      = $xWebService;
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
                        Source      = $ResourcePath -f "$NodeChildPath\$PullNodeGUID.meta.mof";
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
                        Source      = $ResourcePath -f "$NodeChildPath\$FirstDomainControllerGUID.meta.mof";
                        Destination = 'Windows\System32\Configuration\metaconfig.mof'
                    }
                    @{
                        #Kickstart the configuration without having to wait on the pull server.
                        Source      = $ResourcePath -f "$NodeChildPath\$FirstDomainControllerGUID.mof";
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
            
            SecondDomainController = @{
                MachineName     = "$($VMPrefix)SecondDomainController"
                MemorySizeVM    = 2048MB
                VMGeneration    = 2
                VMFileCopy      = @(
                    #Insert metaconfig file for Domain Controller
                    
                )
            }
        }
    );
    NonNodeData = @{
        PullServerAddress = $PullServerIP
        PullServerPort = 8080
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
                Source      = $ResourcePath -f 'Certificates\rusthawk-root-ca_RUSTHAWK-ROOT-CA.crt'
                Destination = 'Scripts\rootcert.crt'
            }
        )
    }
   
}
