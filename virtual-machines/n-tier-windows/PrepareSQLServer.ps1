configuration SQLServerPrepareDsc
{
    param
    (
        [Parameter(Mandatory=$true)]
        [String]$DomainName,

        [Parameter(Mandatory=$false)]
		[String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$SQLServiceCreds,

        [Parameter(Mandatory=$true)]
        [String]$ClusterName,

        [Parameter(Mandatory=$true)]
        [String]$ClusterOwnerNode,

        [Parameter(Mandatory=$true)]
        [String]$ClusterIP=10.0.3.5,

        [Parameter(Mandatory=$true)]
        [String]$witnessStorageAccount,

        [Parameter(Mandatory=$false)]
        [String]$witnessEndpoint="core.windows.net",

        [Parameter(Mandatory=$true)]
        [String]$witnessStorageAccountKey,

        [Parameter(Mandatory=$false)]
        [Int]$RetryCount=20,

        [Parameter(Mandatory=$false)]
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, StorageDsc, xSmbShare, xComputerManagement, xNetworking, xActiveDirectory, xFailoverCluster, SqlServer, SqlServerDsc
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)

    $ipcomponents = $ClusterIP.Split('.')
    $ipcomponents[3] = [convert]::ToString(([convert]::ToInt32($ipcomponents[3])) + 1)
    $ipdummy = $ipcomponents -join "."
    $ClusterNameDummy = "c" + $ClusterName

    $computerName = $env:COMPUTERNAME
    $domainUserName = $DomainCreds.UserName.ToString()

    WaitForSqlSetup

    Node localhost
    {
        WaitforDisk Disk2
        {
            DiskId = 2
            RetryIntervalSec = 60
            RetryCount = 20
        }

        Disk FDisk
        {
            DiskId = 2
            DriveLetter = 'F'
            FSLabel = 'Data'
            FSFormat = 'NTFS'
            DependsOn = '[WaitForDisk]Disk2'
        }

        xFirewall DatabaseEngineFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Database-Engine-TCP-In"
            DisplayName = "SQL Server Database Engine (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Engine."
            Group = "SQL Server"
            Enabled = "True"
            Protocol = "TCP"
            LocalPort = "1433"
            Ensure = "Present"
        }

        xFirewall DatabaseMirroringFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Database-Mirroring-TCP-In"
            DisplayName = "SQL Server Database Mirroring (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Mirroring."
            Group = "SQL Server"
            Enabled = "True"
            Protocol = "TCP"
            LocalPort = "5022"
            Ensure = "Present"
        }

        xFirewall ListenerFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Availability-Group-Listener-TCP-In"
            DisplayName = "SQL Server Availability Group Listener (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Availability Group listener."
            Group = "SQL Server"
            Enabled = "True"
            Protocol = "TCP"
            LocalPort = "59999"
            Ensure = "Present"
        }

        WindowsFeature FC
        {
            Name = "Failover-Clustering"
            Ensure = "Present"
        }

        WindowsFeature FailoverClusterTools 
        { 
            Ensure = "Present" 
            Name = "RSAT-Clustering-Mgmt"
            DependsOn = "[WindowsFeature]FC"
        } 

        WindowsFeature FCPS
        {
            Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]FailoverClusterTools"
        }

        WindowsFeature FCPSCMD
        {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-CmdInterface'
            DependsOn = '[WindowsFeature]FCPS'
        }

        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        }

        SqlServerLogin AddDomainAdminAccountToSqlServer
        {
            Name = $DomainCreds.UserName
            LoginType = "WindowsUser"
			ServerName = "$env:COMPUTERNAME"
			InstanceName = "MSSQLSERVER"
        }

        xADUser CreateSqlServerServiceAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SQLServicecreds.UserName
            Password = $SQLServicecreds
            Ensure = "Present"
            DependsOn = "[SqlServerLogin]AddDomainAdminAccountToSqlServer"
        }

        SqlServerLogin AddClusterSvcAccountToSqlServer
        {
            Name = "NT SERVICE\ClusSvc"
            LoginType = "WindowsUser"
			ServerName = "$env:COMPUTERNAME"
			InstanceName = "MSSQLSERVER"
        }

        #TODO: Create a special group for "NT SERVICE\clusterSvc" and grant only 'Connect SQL', 
        #      'Alter Any Availability Group', and 'View Server State' permissions.
		SqlServerRole AddDomainAdminAccountToSysAdmin
        {
			Ensure = "Present"
            MembersToInclude = $DomainCreds.UserName,"NT SERVICE\ClusSvc"
            ServerRoleName = "sysadmin"
			ServerName = "$env:COMPUTERNAME"
			InstanceName = "MSSQLSERVER"
			DependsOn = "[SqlServerLogin]AddDomainAdminAccountToSqlServer","[SqlServerLogin]AddClusterSvcAccountToSqlServer"
        }

        #TODO: We should create a dedicated user for this.
        SqlServiceAccount SetServiceAcccount_User
        {
			ServerName = "$env:COMPUTERNAME"
			InstanceName = "MSSQLSERVER"
            ServiceType    = 'DatabaseEngine'
            ServiceAccount = $DomainCreds
            RestartService = $true
            DependsOn = "[SqlServerRole]AddDomainAdminAccountToSysAdmin"
        }


        #The SPNs seem to end up in the wrong containers (COMPUTERNAME) as opposed to Domain user
        #This is a bit of a hack to make sure it is straight. 
        Script ResetSpns
        {
            GetScript = { 
                return @{ 'Result' = $true }
            }

            SetScript = {
                $spn = "MSSQLSvc/" + $using:computerName + "." + $using:DomainName
                
                $cmd = "setspn -D $spn $using:computerName"
                Write-Verbose $cmd
                Invoke-Expression $cmd

                $cmd = "setspn -A $spn $using:domainUsername"
                Write-Verbose $cmd
                Invoke-Expression $cmd

                $spn = "MSSQLSvc/" + $using:computerName + "." + $using:DomainName + ":1433"
                
                $cmd = "setspn -D $spn $using:computerName"
                Write-Verbose $cmd
                Invoke-Expression $cmd

                $cmd = "setspn -A $spn $using:domainUsername"
                Write-Verbose $cmd
                Invoke-Expression $cmd
            }

            TestScript = {
                $false
            }

            DependsOn = "[SqlServiceAccount]SetServiceAcccount_User"
            PsDscRunAsCredential = $DomainCreds
        }


        if ($ClusterOwnerNode -eq $env:COMPUTERNAME) { #This is the primary
            xCluster CreateCluster
            {
                Name                          = $ClusterNameDummy
                StaticIPAddress               = $ipdummy
                DomainAdministratorCredential = $DomainCreds
                DependsOn                     = "[WindowsFeature]FCPSCMD","[Script]ResetSpns"
            }

            Script SetCloudWitness
            {
                GetScript = { 
                    return @{ 'Result' = $true }
                }
                SetScript = {
                    Set-ClusterQuorum -CloudWitness -AccountName $using:witnessStorageAccount -AccessKey $using:witnessStorageAccountKey -Endpoint $using:witnessEndpoint
                }
                TestScript = {
                    $(Get-ClusterQuorum).QuorumResource.ResourceType -eq "Cloud Witness"
                }
                DependsOn = "[xCluster]CreateCluster"
                PsDscRunAsCredential = $DomainCreds
            }

            SqlAlwaysOnService EnableAlwaysOn
            {
                Ensure               = 'Present'
                ServerName           = $env:COMPUTERNAME
                InstanceName         = 'MSSQLSERVER'
                RestartTimeout       = 120
                DependsOn = "[xCluster]CreateCluster"
            }

            # Create a DatabaseMirroring endpoint
            SqlServerEndpoint HADREndpoint
            {
                EndPointName         = 'HADR'
                Ensure               = 'Present'
                Port                 = 5022
                ServerName           = $env:COMPUTERNAME
                InstanceName         = 'MSSQLSERVER'
                DependsOn            = "[SqlAlwaysOnService]EnableAlwaysOn"
            }

            # Create the availability group on the instance tagged as the primary replica
            SqlAG CreateAG
            {
                Ensure               = "Present"
                Name                 = $ClusterName
                ServerName           = $env:COMPUTERNAME
                InstanceName         = 'MSSQLSERVER'
                DependsOn            = "[SqlServerEndpoint]HADREndpoint","[SqlServerRole]AddDomainAdminAccountToSysAdmin"
                AvailabilityMode     = "SynchronousCommit"
                FailoverMode         = "Automatic" 
            }

            SqlAGListener AvailabilityGroupListener
            {
                Ensure               = 'Present'
                ServerName           = $ClusterOwnerNode
                InstanceName         = 'MSSQLSERVER'
                AvailabilityGroup    = $ClusterName
                Name                 = $ClusterName
                IpAddress            = "$ClusterIP/255.255.255.0"
                Port                 = 1433
                PsDscRunAsCredential = $DomainCreds
                DependsOn            = "[SqlAG]CreateAG"
            }

            Script SetProbePort
            {

                GetScript = { 
                    return @{ 'Result' = $true }
                }
                SetScript = {
                    $ipResourceName = $using:ClusterName + "_" + $using:ClusterIP
                    $ipResource = Get-ClusterResource $ipResourceName
                    $clusterResource = Get-ClusterResource -Name $using:ClusterName 

                    Set-ClusterParameter -InputObject $ipResource -Name ProbePort -Value 59999

                    Stop-ClusterResource $ipResource
                    Stop-ClusterResource $clusterResource

                    Start-ClusterResource $clusterResource #This should be enough
                    Start-ClusterResource $ipResource #To be on the safe side

                }
                TestScript = {
                    $ipResourceName = $using:ClusterName + "_" + $using:ClusterIP
                    $resource = Get-ClusterResource $ipResourceName
                    $probePort = $(Get-ClusterParameter -InputObject $resource -Name ProbePort).Value
                    Write-Verbose "ProbePort = $probePort"
                    ($(Get-ClusterParameter -InputObject $resource -Name ProbePort).Value -eq 59999)
                }
                DependsOn = "[SqlAGListener]AvailabilityGroupListener"
                PsDscRunAsCredential = $DomainCreds
            }
        } else {
            xWaitForCluster WaitForCluster
            {
                Name             = $ClusterNameDummy
                RetryIntervalSec = 10
                RetryCount       = 60
                DependsOn        = "[WindowsFeature]FCPSCMD","[Script]ResetSpns"
            }

            #We have to do this manually due to a problem with xCluster:
            #  see: https://github.com/PowerShell/xFailOverCluster/issues/7
            #      - Cluster is added with an IP and the xCluster module tries to access this IP. 
            #      - Cluster is not not yet responding on that addreess
            Script JoinExistingCluster
            {
                GetScript = { 
                    return @{ 'Result' = $true }
                }
                SetScript = {
                    $targetNodeName = $env:COMPUTERNAME
                    Add-ClusterNode -Name $targetNodeName -Cluster $using:ClusterOwnerNode
                }
                TestScript = {
                    $targetNodeName = $env:COMPUTERNAME
                    $(Get-ClusterNode -Cluster $using:ClusterOwnerNode).Name -contains $targetNodeName
                }
                DependsOn = "[xWaitForCluster]WaitForCluster"
                PsDscRunAsCredential = $DomainCreds
            }

            SqlAlwaysOnService EnableAlwaysOn
            {
                Ensure               = 'Present'
                ServerName           = $env:COMPUTERNAME
                InstanceName         = 'MSSQLSERVER'
                RestartTimeout       = 120
                DependsOn = "[Script]JoinExistingCluster"
            }

            # Create a DatabaseMirroring endpoint
            SqlServerEndpoint HADREndpoint
            {
                EndPointName         = 'HADR'
                Ensure               = 'Present'
                Port                 = 5022
                ServerName           = $env:COMPUTERNAME
                InstanceName         = 'MSSQLSERVER'
                DependsOn            = "[SqlAlwaysOnService]EnableAlwaysOn"
            }


            SqlWaitForAG WaitForAG
            {
                Name                 = $ClusterName
                RetryIntervalSec     = 20
                RetryCount           = 30
                PsDscRunAsCredential = $DomainCreds
                DependsOn                  = "[SqlServerEndpoint]HADREndpoint","[SqlServerRole]AddDomainAdminAccountToSysAdmin"
            }
      
            # Add the availability group replica to the availability group
            SqlAGReplica AddReplica
            {
                Ensure                     = 'Present'
                Name                       = $env:COMPUTERNAME
                AvailabilityGroupName      = $ClusterName
                ServerName                 = $env:COMPUTERNAME
                InstanceName               = 'MSSQLSERVER'
                PrimaryReplicaServerName   = $ClusterOwnerNode
                PrimaryReplicaInstanceName = 'MSSQLSERVER'
                PsDscRunAsCredential = $DomainCreds
                AvailabilityMode     = "SynchronousCommit"
                FailoverMode         = "Automatic"
                DependsOn            = "[SqlWaitForAG]WaitForAG"     
            }

        }

        LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
    }
}

configuration SQLServerDBDsc
{
    param
    (
        [Parameter(Mandatory=$true)]
        [String]$DomainName,

        [Parameter(Mandatory=$false)]
		[String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory=$true)]
        [String]$ClusterName,

        [Parameter(Mandatory=$true)]
        [String]$ClusterOwnerNode
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, StorageDsc, xSmbShare, SqlServer, SqlServerDsc

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
    {
        if ($ClusterOwnerNode -eq $env:COMPUTERNAME)
        {
            WaitForVolume FVolume
            {
                DriveLetter = 'F'
            }

            File BackupDirectory
            {
                Ensure = "Present" 
                Type = "Directory" 
                DestinationPath = "F:\Backup"
                DependsOn = '[WaitForVolume]FVolume'
            }

            xSMBShare DBBackupShare
            {
                Name = "DBBackup"
                Path = "F:\Backup"
                Ensure = "Present"
                FullAccess = $DomainCreds.UserName
                Description = "Backup share for SQL Server"
                DependsOn = "[File]BackupDirectory"
            }

            SqlDatabase Create_Database
            {
                Ensure       = 'Present'
                ServerName   = $env:COMPUTERNAME
                InstanceName = 'MSSQLSERVER'
                Name         = 'Ha-Sample'
                PsDscRunAsCredential    = $DomainCreds
                DependsOn               = "[xSMBShare]DBBackupShare"
            }
            
            SqlAGDatabase AddDatabaseToAG
            {
                AvailabilityGroupName   = $ClusterName
                BackupPath              = "\\" + $env:COMPUTERNAME + "\DBBackup"
                DatabaseName            = 'Ha-Sample'
                InstanceName            = 'MSSQLSERVER'
                ServerName              = $env:COMPUTERNAME
                Ensure                  = 'Present'
                ProcessOnlyOnActiveNode = $true
                PsDscRunAsCredential    = $DomainCreds
                DependsOn = "[SqlDatabase]Create_Database"
            }
        }

        LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
    }
}

function Get-NetBIOSName
{ 
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
}

function WaitForSqlSetup
{
    # Wait for SQL Server Setup to finish before proceeding.
    while ($true)
    {
        try
        {
            Get-ScheduledTaskInfo "\ConfigureSqlImageTasks\RunConfigureImage" -ErrorAction Stop
            Start-Sleep -Seconds 5
        }
        catch
        {
            break
        }
    }
}