Configuration PullNodeLCM4 {
    Node "metaconfig" {
        LocalConfigurationManager {
            ConfigurationModeFrequencyMins = 30
            ConfigurationMode = "ApplyAndAutoCorrect"
            RefreshMode = "Pull"
            RefreshFrequencyMins = 30
            DownloadManagerName = "WebDownloadManager"
            DownloadManagerCustomData = @{ServerUrl="http://pull.red-hawk.net:8080/psdscpullserver.svc";
                                          AllowUnsecureConnection = 'true'
                                         }

            ConfigurationID = 'bc95ceed-2d57-45d5-b1b1-7602b5b1cbfc'
            RebootNodeIfNeeded = $true
            AllowModuleOverwrite = $false

        }

    }
}

PullNodeLCM4 -outputpath "\\hawkwing\dsc\pullnode"