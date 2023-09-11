﻿# SQL Server Failover Cluster Instance with Azure Shared Disk
This template will provision a base two-node SQL Server Failover Cluster Instance with Azure Shared Disk.

This template creates the following resources in the selected Azure Region:

+	Proximity Placement Group and Availability Set for cluster node VMs
+   Two cluster node Azure VMs running Windows Server 2019 and SQL Server 2019
+   Azure VM DSC Extensions to prepare and configure the SQL Failover Cluster Instance
+   Azure Shared Data Disks for Data and Log (either separate disks or combined on a single disk)
+   Cluster Witness resources (either Storage Account or Shared Disk depending on value of witnessType template parameter)
+   Internal Load Balancer to provide a listener IP Address for clustered workloads that require it.
+   Azure Load Balancer for outbound SNAT support

## Prerequisites

To successfully deploy this template, the following must already be provisioned in your subscription:

+   Azure Virtual Network with subnet defined for cluster node VMs and ILB
+   Windows Server Active Directory and AD-integrated Dynamic DNS reachable from Azure Virtual Network
+   Subnet IP address space defined in AD Sites and Services
+   Custom DNS Server Settings configured on Azure Virtual Network to point to AD-integrated Dynamic DNS servers
+   AD domain user account to be used as service account for SQL Server services

## Template Deployment Notes

+ existingSubnetResourceId parameter
    + When deploying this template, you must supply a valid Azure Resource ID for an existing Virtual Network subnet on which to provision the cluster instances.  You can find the Azure Resource ID value to use by running the PowerShell cmdlet below.

    `(Get-AzVirtualNetwork -Name $(Read-Host -Prompt "Existing VNET name")).Subnets.Id`

+ To deploy the required Azure VNET and Active Directory infrastructure, if not already in place, you may use <a href="https://github.com/Azure/azure-quickstart-templates/tree/master/application-workloads/active-directory/active-directory-new-domain-ha-2-dc-zones">this template</a> to deploy the prerequisite infrastructure. 

+   Currently, Azure Shared Disk is a Preview feature and is available in a subset of Azure regions. Please review the <a href="https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disks-shared-enable">official documentation</a> for more details and current status for this feature.

## Deploying Sample Templates

Click the button below to deploy from the portal:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Frobotechredmond%2F301-shared-disk-sqlfci%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Frobotechredmond%2F301-shared-disk-sqlfci%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Frobotechredmond%2F301-shared-disk-sqlfci%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

Tags: ``cluster, ha, shared disk, sql server 2019, sql2019``
