Configuration PullServer {

    Import-DscResource -ModuleName xPSDesiredStateConfiguration,xNetworking,xComputerManagement

    Node 'pullserver_pending' {
        WindowsFeature DSCService {
            Ensure = "Present"
            Name = "DSC-Service"
        }
        xDSCWebService PullServer {
            CertificateThumbPrint = "AllowUnencryptedTraffic"
            EndpointName = "DSCPullServer"
            ConfigurationPath = "$env:ProgramFiles\WindowsPowerShell\DSCService\Configuration"
            DependsOn = "[WindowsFeature]DSCService"
            Ensure = "Present"
            IsComplianceServer = $false
            ModulePath = "$env:ProgramFiles\WindowsPowerShell\DSCService\Modules"
            PhysicalPath = "$env:SystemDrive\inetpub\wwwroot\DSCPullServer"
            Port = 8080
            RegistrationKeyPath = "$env:ProgramFiles\WindowsPowerShell\DSCService\registration.txt"
            State = "Started"
        }
        xIPAddress SetIP {
            IPAddress = '172.16.10.150'
            SubnetMask = '24'
            InterfaceAlias = "Ethernet"
            AddressFamily = 'IPv4'

        }
        xComputer SetName {
            Name = 'DEV-PULL-SERVER'
            WorkGroupName = 'WORKGROUP'
        }
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ActionAfterReboot = 'ContinueConfiguration'
            
        }
    }
}
PullServer -Outputpath '\\hawkwing\DSC\'
