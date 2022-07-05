# Pre-req: install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux
# curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# curl https://getcroc.schollz.com | bash

echo "Login to Azure"
#az login

echo "Creating resource group"
RESOURCE_GROUP=gktest
LOCATION=eastus
CLUSTER_NAME=setupdadi
NODEPOOL_NAME=testaccel
NODE_COUNT=3

az group create -g $RESOURCE_GROUP -l $LOCATION

echo "Creating AKS cluster"
az aks create -n $CLUSTER_NAME -l $LOCATION -g $RESOURCE_GROUP

echo "Creating user nodepool"
az aks nodepool add \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --name $NODEPOOL_NAME \
    --node-count $NODE_COUNT

echo "Get credentials of AKS cluster"
az aks get-credentials -n $CLUSTER_NAME -g $RESOURCE_GROUP

echo "Done"
