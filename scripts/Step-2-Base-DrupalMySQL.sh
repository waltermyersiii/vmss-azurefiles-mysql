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

# Create a VNet rule on the server to create service endpoint, only traffic from $spokeAppSubnet allowed to access SQL server.
echo "Creating MySQL Service Endpoint"
az mysql server vnet-rule create \
--name myRule \
--resource-group $rg \
--server-name $mysqlprimary \
--vnet-name $spokeVNet \
--subnet $spokeAppSubnet
