#!/bin/bash

#######################
### RUN THIS THIRD  ###
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
# Be sure to update mysqlFQDN based on MySQL script!!!
mysqlprimary="drupalmysqlprimary907"
mysqlreplica1="drupalmysqlreplica1907"
mysqlFQDN="drupalmysqlprimary906.mysql.database.azure.com"
mysqlNewDBName="n/a"

# Create storage account for Azure file share
echo "Creating storage account for Azure file share"
export storageAccountName="waltermdrupalstorage"

# Create storage account for Azure file share
echo "Creating storage account for Azure file share"
export storageAccountName="waltermdrupalstorage"

echo "Storage Account Name is" $storageAccountName

az storage account create \
    --resource-group $rg \
    --name $storageAccountName \
    --location $primaryRegion \
    --kind StorageV2 \
    --sku Standard_LRS \
    --enable-large-file-share

export shareName="data"
export mntPath="/mnt/$storageAccountName/$shareName"

echo "Storage Account Name is" $storageAccountName

# Get the storage account key
export storageAccountKey=$(az storage account keys list \
    --resource-group $rg \
    --account-name $storageAccountName \
    --query "[0].value" | tr -d '"')

# Strip off trailing CR
storageAccountKey="${storageAccountKey//[$'\t\r\n ']}"

# Create Azure file share
echo "Creating Azure file share"
az storage share create \
    --account-name $storageAccountName \
    --account-key $storageAccountKey \
    --name $shareName \
    --quota 1024

# Create Egress-only Load Balancer
az network public-ip create \
    --resource-group $rg \
    --name egressPIP \
    --sku Standard

az network lb create \
  --resource-group $rg \
  --name egressOnlyLB \
  --frontend-ip-name egressFrontEndIP \
  --sku Standard \
  --public-ip-address egressPIP \
  --backend-pool-name egressBackendPool

# Create Internal Load Balancer
az network lb create  \
  --resource-group $rg \
  --name $scalesetLB  \
  --frontend-ip-name myFrontendIp \
  --sku Standard \
  --vnet-name $spokeVNet \
  --subnet $spokeAppSubnet  

#--private-ip-address $spokeAppSubnetPrivateIPAddress

# az network lb frontend-ip create \
#   --resource-group $rg \
#   --name myFrontendIp \
#   --lb-name $scalesetLB \
#   --vnet-name $spokeVNet \
#   --subnet $spokeAppSubnet

az network lb inbound-nat-pool create \
  --resource-group $rg \
  --lb-name $scalesetLB \
  --name myNatPool \
  --protocol Tcp \
  --frontend-port-range-start 80 \
  --frontend-port-range-end 89 \
  --backend-port 80 \
  --frontend-ip-name myFrontendIp

# Create VM Scale Set
echo "Creating VM Scale Set"
az vmss create \
  --resource-group $rg \
  --name $scaleset \
  --image Canonical:UbuntuServer:16.04-LTS:latest \
  --instance-count $instanceCount \
  --upgrade-policy-mode automatic \
  --vnet-name $spokeVNet \
  --subnet $spokeAppSubnet \
  --lb $scalesetLB \
  --public-ip-address scaleSetLBPublicIP \
  --admin-username $adminUsername \
  --ssh-key-values ~/.ssh/id_rsa.pub

# Mount Azure file shares and install Drupal 8 software
echo "Mount Azure file share and install additional software"
az vmss extension set \
  --publisher Microsoft.Azure.Extensions \
  --version 2.0 \
  --name CustomScript \
  --resource-group $rg \
  --vmss-name $scaleset \
  --settings '{"fileUris": ["https://raw.githubusercontent.com/waltermyersiii/azure-quickstart-templates/master/201-vmss-azure-files-linux/mountazurefiles.sh", "https://raw.githubusercontent.com/waltermyersiii/azure-quickstart-templates/master/301-drupal8-vmss-glusterfs-mysql/scripts/install_drupal.sh"],"commandToExecute": "./mountazurefiles.sh '$storageAccountName' '$storageAccountKey' '$shareName' '$mntPath' '$adminUsername' && sudo bash install_drupal.sh -u '$adminUsername' '-p' '$adminPassword' '-s' '$mysqlFQDN' '-n' '$adminUsername' '-P' '$adminPassword' '-k' '$mysqlNewDBName'"}' \
  --debug
  
# Create Jump Box
az vm create \
  --resource-group $rg \
  --name jumpVM \
  --image UbuntuLTS \
  --vnet-name $spokeVNet \
  --subnet $spokeAppSubnet \
  --admin-username $adminUsername \
  --ssh-key-values ~/.ssh/id_rsa.pub

  # Allow traffic to VMSS
  echo "Allow traffic to VMSS"
  az network lb rule create \
  --resource-group $rg \
  --name myLoadBalancerRuleWeb \
  --lb-name $scalesetLB \
  --backend-pool-name drupalScaleSetLBBEPool \
  --backend-port 80 \
  --frontend-ip-name loadBalancerFrontEnd \
  --frontend-port 80 \
  --protocol tcp

  # Test VMSS
  echo "Get public IP to VMSS"
  az network public-ip show \
  --resource-group $rg \
  --name scaleSetLBPublicIP \
  --query '[ipAddress]' \
  --output tsv
