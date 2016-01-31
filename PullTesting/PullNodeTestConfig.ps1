Configuration PullTestConfig {
    Import-DSCResource -ModuleName PSDesiredStateConfiguration,xComputerManagement
    Node "bc95ceed-2d57-45d5-b1b1-7602b5b1cbfc" {
        xComputer SetName {
            Name = 'PullTestNode01'
        }
        WindowsFeature Bitlocker {
            Ensure = "Present"
            Name = "Bitlocker"
        }
    }
}

PullTestConfig -outputpath \\hawkwing\dsc\pullnode
New-DscChecksum -ConfigurationPath \\hawkwing\dsc\pullnode