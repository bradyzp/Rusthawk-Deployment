<#
    TESTING INITIATOR
#>

Remove-Module DeploymentConfiguration -ErrorAction Ignore

Import-Module $PSScriptRoot\DeploymentConfiguration.psm1
$ConfigData = & "$PSScriptRoot\ConfigurationData.ps1" -HyperVHost hawkwing -dscresourcepath '.\{0}'

Remove-Item $PSScriptRoot\Testing\*.* -Force -Verbose

function Test-HVHostConfig {
    HyperVHost -Role HyperVHost -ConfigurationData $ConfigData -OutputPath $PSScriptRoot\Testing -Verbose

    Get-Content $PSScriptRoot\Testing\*.mof

}

function Test-PullNode {
    PullNode -Role PullNode -ConfigurationData $ConfigData -OutputPath $PSScriptRoot\Testing -Verbose
    Write-Host "PullNode .mof:"
    Get-Content $PSScriptRoot\Testing\*.mof
}

function Test-PullNodeVM {
    PullNodeVM -Role HyperVHost -ConfigurationData $ConfigData -OutputPath $PSScriptRoot\Testing
    Write-Host "PullNodeVM .mof:"
    Get-Content $PSScriptRoot\Testing\*.mof
}




#Test-HVHostConfig

#Test-PullNodeVM

Test-PullNodeVM

<#
Write-Verbose "My Invocation"
$MyInvocation

Write-Verbose "My Invocation.MyCommand"
$MyInvocation.MyCommand
Write-Verbose "My Invocation.MyCommand.Definition"
$MyInvocation.MyCommand.Definition
#>
