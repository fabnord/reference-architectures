#!/usr/bin/env bash


# Creates the resource group

az group create --name "${RGNAME}" --location "${RGLOCATION}"

# Creates the storage account for the resource used by application
az storage account create -n ${STORAGEACCNAME} -g ${RGNAME} -l ${RGLOCATION} --sku standard_LRS

az storage container create -n rsrcontainer  --account-name ${STORAGEACCNAME} --public-access blob

wget ${DEPLOYMENT}Microsoft_Azure_logo_small.png

# Uploads the resource to the blob container
az storage blob upload -c rsrcontainer -f Microsoft_Azure_logo_small.png -n Microsoft_Azure_logo_small.png --account-name ${STORAGEACCNAME}

# it stores the endpoint to the resource 
resourceurl=`az storage account show -n ${STORAGEACCNAME} | jq -r .primaryEndpoints.blob`rsrcontainer/Microsoft_Azure_logo_small.png



# It creates the sql server and sql database with admin user being created
az sql server create -l "${RGLOCATION}"  -g $RGNAME -n $SQLSERVERNAME  -u $SQLADMINUSER -p $SQLADMINPASSWORD

az sql db create -s $SQLSERVERNAME -n $SQLSERVERDB -g $RGNAME

# it stores the connection string to be passed to arm template

connstring=`az sql db show-connection-string --server $SQLSERVERNAME --name $SQLSERVERDB --client ado.net`

connstring=$(echo $connstring | sed "s/<username>/${SQLADMINUSER}/g")
connstring=$(echo $connstring | sed "s/<password>/${SQLADMINPASSWORD}/g")
sqlcon="${connstring%\"}"
sqlcon="${sqlcon#\"}"


az sql server firewall-rule create -g $RGNAME -s $SQLSERVERNAME  -n azureservices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# it creates the tables in the database

sqlcmd -S tcp:${SQLSERVERNAME}.database.windows.net,1433 -d votingdb -U $SQLADMINUSER -P $SQLADMINPASSWORD -N -l 30 -Q "CREATE TABLE Counts(ID INT NOT NULL IDENTITY PRIMARY KEY, Candidate VARCHAR(32) NOT NULL, Count INT)"

# it runs the arm template deployment passing the dns name of gateway
# the certificate and its password 
az group deployment create --resource-group $RGNAME --template-uri ${DEPLOYMENT}webappdeploy.json --parameters VotingWeb_name=${DNSNAME} SqlConnectionString="$sqlcon" 

cosmosacc=`az cosmosdb list -g ${RGNAME} | jq -r .[0].name`

az cosmosdb database create -d cacheDB -n ${cosmosacc} -g ${RGNAME}

az cosmosdb collection create --name ${cosmosacc} -c cacheContainer -g ${RGNAME} --db-name cacheDB --partition-key-path '/MessageType'



	 
	 
      

