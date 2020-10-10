#!/bin/bash

#######################
### RUN THIS SECOND ###
#######################

rg="DrupalInfra"
primaryRegion="eastus2"
secondaryRegion="centralus"
spokeVNet="spokeVNet"
spokeVNetAddressPrefix="10.0.0.0/16"
spokeAppSubnet="spokeAppSubnet"
spokeAppSubnetAddressPrefix="10.0.1.0/24"
spokeDBSubnet="spokeDBSubnet"
spokeDBSubnetAddressPrefix="10.0.2.0/24"
scaleset="drupalScaleSet"
scalesetLB="drupalScaleSetLB"
instanceCount="2"
adminUsername="drupaladmin"
adminPassword="tst909@@10"
privEndpointConnection="mysqlprivendconn"

# MySQL related parameters 
mysqlprimary="drupalmysqlprimary"
mysqlreplica1="drupalmysqlreplica1"

# Create a mySQL Server
echo "Creating MySQL name $mysqlprimary in region $primaryRegion"
az mysql server create \
--name $mysqlprimary \
--resource-group $rg \
--location $primaryRegion \
--admin-user myadmin \
--admin-password $adminPassword \
--assign-identity \
--sku-name GP_Gen5_2 \
--backup-retention 35 \
--auto-grow Enabled \
--storage-size 51200

# Adding mySQL replica server in in secondaryRegion
echo "Creating MySQL Replica $mysqlreplica1 in $secondaryRegion region"
az mysql server replica create \
--name $mysqlreplica1 \
--resource-group $rg \
--source-server $mysqlprimary \
--location $secondaryRegion

# be sure to add --service-endpoints Microsoft.SQL while creating App subnet.

# Create a private endpoint for the MySQL server in your Virtual Network
echo "Create a private endpoint for the MySQL server"
az network private-endpoint create \
    --name myPrivateEndpoint \
    --resource-group $rg \
    --vnet-name $spokeVNet \
    --subnet $spokeDBSubnet \
    --private-connection-resource-id $(az resource show -g $rg -n $mysqlprimary --resource-type "Microsoft.DBforMySQL/servers" --query "id" -o tsv) \
    --connection-name $privEndpointConnection \
    --group-id mysqlServer

#Create a Private DNS Zone for MySQL server domain and create an association link with the Virtual Network.
echo "Create Private DNS Zone for MySQL server"
az network private-dns zone create --resource-group $rg \
   --name  "privatelink.mysql.database.azure.com"

echo "Create private dns link"
az network private-dns link vnet create \
   --resource-group $rg \
   --zone-name  "privatelink.mysql.database.azure.com"\
   --name MyDNSLink \
   --virtual-network $spokeVNet \
   --registration-enabled false

#Query for the network interface ID
echo "Query for network interface ID"
networkInterfaceId=$(az network private-endpoint show --name myPrivateEndpoint --resource-group $rg --query 'networkInterfaces[0].id' -o tsv)

echo "Get private IP Address"
az resource show --ids $networkInterfaceId --api-version 2019-04-01 -o json 
# Copy the content for private IPAddress and FQDN matching the Azure database for MySQL name 

#Create DNS records
echo "Create DNS records"
az network private-dns record-set a create --name myserver --zone-name privatelink.mysql.database.azure.com --resource-group $rg  
#az network private-dns record-set a add-record --record-set-name myserver --zone-name privatelink.mysql.database.azure.com --resource-group $rg -a <Private IP Address of the private link>
