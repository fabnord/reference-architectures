# Web application Deployment

#### Step 1 Create directory and  the environment variables to run the deployment script.

Open an azure cloud shell and run below commands.

**Note:** RGLOCATION should be in the right format. Some examples of valid locations are **westus, eastus, northeurope, westeurope, eastasia, southeastasia, northcentralus, southcentralus, centralus, eastus2, westus2, japaneast, japanwest, brazilsouth**. The DNSNAME and STORAGEACCNAME should be **unique and valid**. You will test uniqueness and validity of them after this step.

```
mkdir deployweb
cd deployweb
```
```
export DEPLOYMENT=https://raw.githubusercontent.com/mspnp/reference-architectures/master/web-app/deployment/
export RGNAME=resourceGroupName
export RGLOCATION=yourLocation
export SQLSERVERNAME=yourSqlServerName
export SQLSERVERDB=yousqlSqlServerDb
export SQLADMINUSER=yoursqlAdminUser
export DNSNAME=uniquednsnameOfWebApp
export STORAGEACCNAME=yourstorageaccountName
```

#### Step 2 Check if the dns name of gateway is available and is valid

Enter the bellow commands. If the Dns name is not valid or not available go back and change the DNSNAME value.

```
token=`az account get-access-token | jq -r .accessToken`

curl -H "Authorization: Bearer ${token}" "https://management.azure.com/subscriptions/d0d422cd-e446-42aa-a2e2-e88806508d3b/providers/Microsoft.Network/locations/${RGLOCATION}/CheckDnsNameAvailability?domainNameLabel=${DNSNAME}&api-version=2018-11-01"
```

#### Step 3 Check if storage account name is valid and is available

Enter the below command. If the storage account is not available or not valid go back on step 1 and change the STORAGEACCNAME value.

```
az storage account check-name -n ${STORAGEACCNAME}
```




#### Step 4 Enter the password for the sql server administrator and export the variable to be used by the deployment script.

**Note:** Sql administrator has a minimum password size of 8 characters requirement. For sql password requirements Check https://docs.microsoft.com/en-us/sql/relational-databases/security/password-policy?view=sql-server-2017 for Sql administrator password requirements


```
```
read -s SQLADMINPASSWORD
export SQLADMINPASSWORD
```

#### Step 5 From the azure cloud shell download the deployment script, assign execute permissions and run it

```
wget ${DEPLOYMENT}rundeployment.sh
chmod +x rundeployment.sh
```
```
./rundeployment.sh
```

#### Step 6 Insert Document in Cosmos Db
1. After deployment ends in the last step, run below commands to get the resourceURl

```
resourceurl=`az storage account show -n ${STORAGEACCNAME} | jq -r .primaryEndpoints.blob`rsrcontainer/Microsoft_Azure_logo_small.png
echo $resourceurl
```
Copy that value from above command and paste it in  json content below replacing resourceurl

```
{"id": "1","Message": "Powered by Azure","MessageType": "AD","Url": "resourceurl"}
```
example correct json
```
{"id": "1","Message": "Powered by Azure","MessageType": "AD","Url": "https://webappri.blob.core.windows.net/webappri/Microsoft_Azure_logo_small.png"}
```
2. Go to azure portal in the resource group of deployment above and click on **Azure Cosmos Db Account** then select **cacheContainer** then click on **Documents**. Click on **New Document**. Replace the whole json payload with above content and click **Save**

#### Step 7 Publish Asp.net core Web, Api and Function applications.

1. Clone the repo. Open Votin.sln solution right click on VotingData click on **Publish**, select **new profile** then click on **existing**, select the resource group for the deployment select the votingdata api app service deployment.

2. Open visual studio  right click on VotingWeeb click on **Publish**, select **new profile** then click on **existing**, select the resource group for the deployment select the votingweb app service deployment.

3. Open FunctionVoteCounter.sln solution right click on VoteCounter project click on **Publish**, select **new profile** then click on **existing**, select the resource group select the function app service deployment.

4. At this point you should be able to test the application. Open the url https://yourwebfrontend.yourlocation.cloudapp.azure.com/. Ignore the certificate validation error on the browser.
