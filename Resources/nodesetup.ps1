#Force LCM to process a pending metaconfig.mof file by calling the CimMethod

function StartLCM
{
	param(
        [ValidateSet(1,2,3)]
	    [system.uint32]$flag = 1
    )
    
    $CimArguments = @{
        "Namespace" = "root/microsoft/windows/desiredstateconfiguration"
        "ClassName" = "MSFT_DSCLocalConfigurationManager"
        "Name" = "PerformRequiredConfigurationChecks"
        "Arguments" = @{Flags = $flag}
        "Verbose" = $true
    }
	Invoke-CimMethod @CimArguments
}

StartLCM
