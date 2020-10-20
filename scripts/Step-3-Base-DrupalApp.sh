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
mysqlprimary="drupalmysqlprimary907"
mysqlreplica1="drupalmysqlreplica1907"

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

# Mount Azure file shares and install additional software
echo "Mount Azure file share and install additional software"
az vmss extension set \
  --publisher Microsoft.Azure.Extensions \
  --version 2.0 \
  --name CustomScript \
  --resource-group $rg \
  --vmss-name $scaleset \
  --settings '{"fileUris":["https://raw.githubusercontent.com/waltermyersiii/azure-quickstart-templates/master/201-vmss-azure-files-linux/mountazurefiles.sh","https://raw.githubusercontent.com/Azure-Samples/compute-automation-configurations/master/automate_nginx.sh"],"commandToExecute":"./mountazurefiles.sh '$storageAccountName' '$storageAccountKey' '$shareName' '$mntPath' '$adminUsername' && ./automate_nginx.sh"}'
  
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
