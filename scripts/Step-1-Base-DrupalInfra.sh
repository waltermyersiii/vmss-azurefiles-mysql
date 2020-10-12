#!/bin/bash

#######################
### RUN THIS FIRST  ###
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
mysqlprimary="drupalmysqlprimary904"
mysqlreplica1="drupalmysqlreplica1904"

# Create a resource group.
echo "Creating Resource Group"
az group create --name $rg --location $primaryRegion

# Create VNet
echo "Creating Virtual Network"
az network vnet create \
  --name $spokeVNet \
  --resource-group $rg \
  --address-prefixes $spokeVNetAddressPrefix \
  --subnet-name $spokeAppSubnet \
  --subnet-prefix $spokeAppSubnetAddressPrefix

echo "Add Service Endpoint to App Subnet"
az network vnet subnet update  \
  --resource-group $rg \
  --name $spokeAppSubnet \
  --vnet-name $spokeVNet \
  --service-endpoints Microsoft.SQL

echo "Add DB Subnet"
az network vnet subnet create \
  --name $spokeDBSubnet \
  --resource-group $rg \
  --vnet-name $spokeVNet \
  --address-prefixes $spokeDBSubnetAddressPrefix

echo "Set private endpoint network policy on DB subnet"
  az network vnet subnet update \
 --name $spokeDBSubnet \
 --resource-group $rg \
 --vnet-name $spokeVNet \
 --disable-private-endpoint-network-policies true
