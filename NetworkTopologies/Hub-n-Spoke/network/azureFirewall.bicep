@description('Virtual Network name')
param vnetName string

@description('Azure region for Bastion and virtual network')
param location string = resourceGroup().location

param azureFirewallName string

@description('Basic, Standard, or Premium')
param azureFirewallSkuTier string

@description('Tags for deployed resources.')
param tags object = {}

var azureFirewallPipName = 'pip-${azureFirewallName}'
var azureFirewallSubnetName = 'AzureFirewallSubnet'

// Reference an existing Azure Firewall Subnet
resource vnetHub 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

// Reference an existing Azure Firewall Subnet
resource azureFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' existing = {
  name: '${vnetName}/${azureFirewallSubnetName}'
}

// Create Azure PIP
resource createAzureFirewallPip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: azureFirewallPipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Create Azure Firewall Policy
module createAzureFirewallPolicy 'firewallPolicy/firewallPolicy.bicep' = {
  name: 'createAzureFirewallPolicy'
  scope: resourceGroup()
  params: {
    location: location
    firewallPolicySku: azureFirewallSkuTier
    adRulesDestinationAddresses: vnetHub.properties.addressSpace.addressPrefixes
    adRulesSourceAddresses: [
      '*'
    ]
    coreSysRulesDestinationAddresses: [
      '*'
    ]
    coreSysRulesSourceAddresses: [
      '*'
    ]
  }
}

// Create Azure Firewall
resource createAzureFirewall 'Microsoft.Network/azureFirewalls@2021-05-01' = {
  name: azureFirewallName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: azureFirewallName
        properties: {
          publicIPAddress: {
            id: createAzureFirewallPip.id
          }
          subnet: {
            id: azureFirewallSubnet.id
          }
        }
      }
    ]
    firewallPolicy: {
      id: createAzureFirewallPolicy.outputs.afwPolicyId
    }
  }
}
