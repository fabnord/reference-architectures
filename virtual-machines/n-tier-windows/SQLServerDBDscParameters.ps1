@{
    ConfigurationData=@{
        AllNodes = @(
            @{
                NodeName="*";
                PSDscAllowPlainTextPassword=$true;
            },
            @{
                NodeName="localhost";
            }
        )
    };
    DomainName="contoso.com";
    Admincreds=New-Object System.Management.Automation.PSCredential('none', `
        $(ConvertTo-SecureString 'none' -AsPlainText -Force));
    ClusterName="AOCluster";
    ClusterOwnerNode="sql1";
}