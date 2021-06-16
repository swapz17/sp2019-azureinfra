<#
.SYNOPSIS
Deploys a virtual machine in Azure using GitHub Actions

.DESCRIPTION 
This script will deploy a virtual machine within Azure utilising  GitHub Actions as the deployment technology. 

.OUTPUTS


.NOTES
Written by: Sarah Lean

Find me on:

* My Blog:	http://www.techielass.com
* Twitter:	https://twitter.com/techielass
* LinkedIn:	http://uk.linkedin.com/in/sazlean
* GitHub:   https://www.github.com/weeyin83


.EXAMPLE


Change Log
V1.00, 06/01/2020 - Initial version

License:

The MIT License (MIT)

Copyright (c) 2017 Sarah Lean

Permission is hereby granted, free of charge, to any person obtaining a copy 
of this software and associated documentation files (the "Software"), to deal 
in the Software without restriction, including without limitation the rights 
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.

#>


[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]
    $servicePrincipal,

    [Parameter(Mandatory = $True)]
    [string]
    $servicePrincipalSecret,

    [Parameter(Mandatory = $True)]
    [string]
    $servicePrincipalTenantId,

    [Parameter(Mandatory = $True)]
    [string]
    $azureSubscriptionName,

    [Parameter(Mandatory = $True)]
    [string]
    $resourceGroupName,

    [Parameter(Mandatory = $True)]
    [string]
    $resourceGroupRegion,

    [Parameter(Mandatory = $True)]  
    [string]
    $frontEndDistServerName1,

    [Parameter(Mandatory = $True)]  
    [string]
    $frontEndDistServerName2,

    [Parameter(Mandatory = $True)]  
    [string]
    $appServerName1,

    [Parameter(Mandatory = $True)]  
    [string]
    $appServerName2,

    [Parameter(Mandatory = $True)]  
    [string]
    $searchServerName1,

    [Parameter(Mandatory = $True)]  
    [string]
    $searchServerName2,

    [Parameter(Mandatory = $True)]  
    [string]
    $databaseServerName1,

    [Parameter(Mandatory = $True)]  
    [string]
    $databaseServerName2,

    [Parameter(Mandatory = $True)]  
    [string]
    $vnetName,

    [Parameter(Mandatory = $True)]  
    [string]
    $appVMSize,

    [Parameter(Mandatory = $True)]  
    [string]
    $dataVMSize,

    [Parameter(Mandatory = $True)]  
    [string]
    $adminLogin,

    [Parameter(Mandatory = $True)]  
    [String]
    $adminPassword
)


#region Login
# This logs into Azure with a Service Principal Account
#
Write-Output "Logging in to Azure with a service principal " $servicePrincipal
az login `
    --service-principal `
    --username $servicePrincipal `
    --password $servicePrincipalSecret `
    --tenant $servicePrincipalTenantId
Write-Output "Logged in to Azure with a service principal " $servicePrincipal
#endregion

#region Subscription
#This sets the subscription the resources will be created in

Write-Output "Setting default azure subscription..."
az account set `
    --subscription $azureSubscriptionName
Write-Output "Default Azure subscription set to " $azureSubscriptionName
#endregion

#region Create Resource Group
# This creates the resource group used to house the VM
Write-Output "Creating resource group $resourceGroupName in region $resourceGroupRegion..."
az group create `
    --name $resourceGroupName `
    --location $resourceGroupRegion
Write-Output "Done creating resource group"
 #endregion

#region create VNET
# App Sunet 123 Usable IPs
az network vnet create `
    --name $vnetName `
    --address-prefixes 10.0.0.0/24 `
    --resource-group $resourceGroupName `
    --subnet-name AppSubnet `
    --subnet-prefixes 10.0.0.0/25 `

# Data Subnet 50 usable IPs
az network vnet subnet create `
	--vnet-name $vnetName `
	--resource-group $resourceGroupName `
	--name DataSubnet `
    --address-prefixes 10.0.0.128/26

# Bastion Subnet 27 usable IPs
az network vnet subnet create `
	--vnet-name $vnetName `
	--resource-group $resourceGroupName `
	--name AzureBastionSubnet `
    --address-prefixes 10.0.0.192/27

#endregion

# WAF Subnet 11 usable IPs
az network vnet subnet create `
	--vnet-name $vnetName `
	--resource-group $resourceGroupName `
	--name WAFSubnet `
    --address-prefixes 10.0.0.224/28

#endregion

#region NSG
az network nsg create `
    --name AppNSG `
    --resource-group $resourceGroupName

az network nsg create `
    --name DataNSG `
    --resource-group $resourceGroupName

#endregion

#region Bastion

az network public-ip create `
    --name BastionHost `
    --resource-group $resourceGroupName `
    --sku Standard

az network bastion create `
    --name SP2019Bastion `
    --public-ip-address BastionHost `
    --resource-group $resourceGroupName `
    --vnet-name $vnetName

#endregion


#region Create VM
# Create a VMs in the resource group
try {
    Write-Output "Creating VM FrontEnd & Distributed Cache 1"
    az vm create  `
        --resource-group $resourceGroupName `
        --name $frontEndDistServerName1 `
        --image win2019datacenter `
        --admin-username $adminLogin `
        --admin-password $adminPassword `
        --public-ip-address '""' `
        --nsg AppNSG `
        --size $appVMSize `
        --os-disk-name ($frontEndDistServerName1 + '_OSDisk')


    Write-Output "Creating VM FrontEnd & Distributed Cache 2"
    az vm create  `
        --resource-group $resourceGroupName `
        --name $frontEndDistServerName2 `
        --image win2019datacenter `
        --admin-username $adminLogin `
        --admin-password $adminPassword `
        --public-ip-address '""' `
        --nsg AppNSG `
        --size $appVMSize `
        --os-disk-name ($frontEndDistServerName2 + '_OSDisk' )
    
    Write-Output "Creating VM Application 1"
    az vm create  `
        --resource-group $resourceGroupName `
        --name $appServerName1 `
        --image win2019datacenter `
        --admin-username $adminLogin `
        --admin-password $adminPassword `
        --public-ip-address '""' `
        --nsg AppNSG `
        --size $appVMSize `
        --os-disk-name ( $appServerName1 + '_OSDisk' )

    Write-Output "Creating VM Application 2"
    az vm create  `
        --resource-group $resourceGroupName `
        --name $appServerName2 `
        --image win2019datacenter `
        --admin-username $adminLogin `
        --admin-password $adminPassword `
        --public-ip-address '""' `
        --nsg AppNSG `
        --size $appVMSize `
        --os-disk-name ( $appServerName2 + '_OSDisk' )
    
    Write-Output "Creating VM Search 1"
    az vm create  `
        --resource-group $resourceGroupName `
        --name $searchServerName1 `
        --image win2019datacenter `
        --admin-username $adminLogin `
        --admin-password $adminPassword `
        --public-ip-address '""' `
        --nsg AppNSG `
        --size $appVMSize `
        --os-disk-name ( $searchServerName1 + '_OSDisk' )

    Write-Output "Creating VM Search 2"
    az vm create  `
        --resource-group $resourceGroupName `
        --name $searchServerName2 `
        --image win2019datacenter `
        --admin-username $adminLogin `
        --admin-password $adminPassword `
        --public-ip-address '""' `
        --nsg AppNSG `
        --size $appVMSize `
        --os-disk-name ( $searchServerName2 + '_OSDisk' )

    Write-Output "Creating VM Database 1"
    az vm create  `
        --resource-group $resourceGroupName `
        --name $databaseServerName1 `
        --image win2019datacenter `
        --admin-username $adminLogin `
        --admin-password $adminPassword `
        --public-ip-address '""' `
        --nsg DataNSG `
        --size $dataVMSize `
        --os-disk-name ( $databaseServerName1 + '_OSDisk' )

    Write-Output "Creating VM Database 2"
    az vm create  `
        --resource-group $resourceGroupName `
        --name $databaseServerName2 `
        --image win2019datacenter `
        --admin-username $adminLogin `
        --admin-password $adminPassword `
        --public-ip-address '""' `
        --nsg DataNSG `
        --size $dataVMSize `
        --os-disk-name ( $databaseServerName2 + '_OSDisk' )


    }
catch {
    Write-Output "VM already exists"
    }
Write-Output "Done creating VM"
#endregion

#region Application Gateway
Write-Output
az network public-ip create `
    --name AppGatewayHost `
    --resource-group $resourceGroupName `
    --sku Standard

$feServer1 = az vm show `
                -g $resourceGroupName `
                -n $frontEndDistServerName1 `
                --show-details --query 'privateIps'
$feServer2 = az vm show `
                -g $resourceGroupName `
                -n $frontEndDistServerName2 `
                --show-details --query 'privateIps'

az network application-gateway create `
    --name Sp2019AppGateway `
    --location centralindia `
    --resource-group $resourceGroupName `
    --capacity 2 `
    --sku Standard_v2 `
    --http-settings-cookie-based-affinity Disabled `
    --public-ip-address AppGatewayHost `
    --vnet-name Sp2019VNet `
    --subnet WAFSubnet `
    --servers "$feServer1" "$feServer2"

#endregion
