<#
.SYNOPSIS
    This script is used to automate and deploy a configured Windows AD Domain environment

.DESCRIPTION
    This script will automate the provisioning and deployment of a basic fully functional windows domain environment - including Domain Controllers/DNS/DHCP/File Share on a Windows Hyper-V Host

.EXAMPLE
    #TBD

.LINK
    #TBD

.NOTES
    Hyper-V Host and BaseVhd must have at least 'Windows Management Framework 5.0 Experimental July 2014 (KB2969050)' installed to run this example.  
     
    List of DSC resources that should be present on the system:
        - xIPAddress
        - xFirewall
        - xComputer
        - xADDomain
        - xADUser
        - xDhcpServerScope
        - xDhcpServerOption
        - xDhcpServerReservation
        - xDnsServerZoneTransfer
        - xDnsServerSecondaryZone
        - xDSCWebService
        - xVHD
        - xVhdFile
        - xVMHyperV
        - xVMSwitch   
#>


param (
    [String]$ConfigPath = "./config"
    )
#---------------------------------#
#Config Generation Block
#---------------------------------#

DSCPullServer          -ConfigurationData $configdata  -Role 'PullServer'   -OutPath $ConfigPath
DomainController       -ConfigurationData $configdata  -Role 'PDC'          -OutPath $ConfigPath
DomainController       -ConfigurationData $configdata  -Role 'DC'           -OutPath $ConfigPath
FileServer             -ConfigurationData $configdata  -Role 'FileServer'   -OutPath $ConfigPath

#Generate DSC Checksum for configs for DSC Pull
New-DSCCheckSum         -ConfigurationPath $ConfigPath






