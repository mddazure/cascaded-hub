param rgName string = 'cascaded-hub-rg-2'
param subscriptionId string = subscription().subscriptionId
param location1 string = 'swedencentral'

param hubName string = 'hub-vnet'
param hubAddressPrefix string = '10.0.0.0/24'
param arssubnetName string = 'RouteServerSubnet'
param arssubnetPrefix string = '10.0.0.64/26'
param gwsubnetName string = 'GatewaySubnet'
param gwsubnetPrefix string = '10.0.0.0/27'
param nvasubnetName string = 'NVA-Subnet'
param nvasubnetPrefix string = '10.0.0.128/26'
param c8k1IPv4 string = '10.0.0.132'
param c8k2IPv4 string = '10.0.0.133'

param cascadedhubName string = 'cascaded-hub-vnet'
param cascadedhubAddressPrefix string = '10.0.1.0/24'
param azfwsubnetName string = 'AzureFirewallSubnet'
param azfwsubnetPrefix string = '10.0.1.64/26'
param azfwmgmntsubnetName string = 'AzureFirewallManagementSubnet'
param azfwmgmntsubnetPrefix string = '10.0.1.128/26'
param bastionsubnetName string = 'AzureBastionSubnet'
param bastionsubnetPrefix string = '10.0.1.192/26'

param spoke1Name string = 'spoke1-vnet'
param spoke1vmsubnetName string = 'spoke1-vm-subnet'
param spoke1AddressPrefix string = '172.16.1.0/24'
param spoke1vmIPv4 string = '172.16.1.4'
param spoke1vmsubnetPrefix string = '172.16.1.0/26'
param spoke2Name string = 'spoke2-vnet'
param spoke2AddressPrefix string = '172.16.2.0/24'
param spoke2vmsubnetName string = 'spoke2-vm-subnet'
param spoke2vmsubnetPrefix string = '172.16.2.0/26'
param spoke3Name string = 'spoke3-vnet'
param spoke3AddressPrefix string = '172.16.3.0/24'
param spoke3vmsubnetName string = 'spoke3-vm-subnet'
param spoke3vmsubnetPrefix string = '172.16.3.0/26'

param adminUser string = 'AzureAdmin'
param adminPw string = 'Cascaded-2025!'

// Define spoke address ranges for firewall rules
var spokeAddressRanges = [
  spoke1AddressPrefix  // 172.16.1.0/24
  spoke2AddressPrefix  // 172.16.2.0/24
  spoke3AddressPrefix  // 172.16.3.0/24
]

// demo application container image
param containerImage string = 'madedroo/azure-region-viewer:latest'

//port backend vm's listen on
param exposedPort int = 80

//port exposed by the container
param containerPort int = 3000

targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location1
}

module hubvnet 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: 'hubVNetDeployment'
  scope: rg
  params: {
    name: hubName
    addressPrefixes: [
      hubAddressPrefix
    ]
    subnets: [
      {
        name: arssubnetName
        addressPrefixes: [
          arssubnetPrefix
        ]

      }
      {
        name: gwsubnetName
        addressPrefixes: [
          gwsubnetPrefix
        ]
      }
      {
        name: nvasubnetName
        addressPrefixes: [
          nvasubnetPrefix
        ]
      }
    ]
    location: location1
    peerings: [

    ]
  }
}
module cascadedhubvnet 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: 'cascadedHubVNetDeployment'
  scope: rg
  params: {
    name: cascadedhubName
    addressPrefixes: [
      cascadedhubAddressPrefix
    ]
    subnets: [
      {
        name: azfwsubnetName
        addressPrefixes: [
          azfwsubnetPrefix
        ]

      }
      {
        name: azfwmgmntsubnetName
        addressPrefixes: [
          azfwmgmntsubnetPrefix
        ]
      }
      {
        name: bastionsubnetName
        addressPrefixes: [
          bastionsubnetPrefix
        ]
      }
    ]
    location: location1
    peerings: [
      {
        name: 'cascaded-hub-to-hub'
        remotePeeringName: 'hub-to-cascaded-hub'
        remoteVirtualNetworkResourceId: hubvnet.outputs.resourceId
        allowVirtualNetworkAccess: true
        allowForwardedTraffic: true
        useRemoteGateways: true
        remotePeeringAllowGatewayTransit: true
        remotePeeringEnabled: true
        remotePeeringAllowForwardedTraffic: true
      }
    ]
  }
}
module spoke1vnet 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: 'spoke1VNetDeployment'
  scope: rg
  params: {
    name: spoke1Name
    addressPrefixes: [
      spoke1AddressPrefix
    ]
    subnets: [
      {
        name: spoke1vmsubnetName
        addressPrefixes: [
          spoke1vmsubnetPrefix
        ]
        routeTableResourceId: spokertable.outputs.resourceId
      }
    ]
    location: location1
    peerings: [
           {
        name: 'spoke1-to-cascaded-hub'
        remotePeeringName: 'cascaded-hub-to-spoke1'
        remoteVirtualNetworkResourceId: cascadedhubvnet.outputs.resourceId
        allowVirtualNetworkAccess: true
        allowForwardedTraffic: true
        remotePeeringEnabled: true
      } 
    ]
  }
}
module spoke2vnet 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: 'spoke2VNetDeployment'
  scope: rg
  params: {
    name: spoke2Name
    addressPrefixes: [
      spoke2AddressPrefix
    ]
    subnets: [
      {
        name: spoke2vmsubnetName
        addressPrefixes: [
          spoke2vmsubnetPrefix
        ]
        routeTableResourceId: spokertable.outputs.resourceId
      }
    ]
    location: location1
    peerings: [
           {
        name: 'spoke2-to-cascaded-hub'
        remotePeeringName: 'cascaded-hub-to-spoke2'
        remoteVirtualNetworkResourceId: cascadedhubvnet.outputs.resourceId
        allowVirtualNetworkAccess: true
        allowForwardedTraffic: true
        remotePeeringEnabled: true
      } 
    ]
  }
}
module spoke3vnet 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: 'spoke3VNetDeployment'
  scope: rg
  params: {
    name: spoke3Name
    addressPrefixes: [
      spoke3AddressPrefix
    ]
    subnets: [
      {
        name: spoke3vmsubnetName
        addressPrefixes: [
          spoke3vmsubnetPrefix
        ]
        routeTableResourceId: spokertable.outputs.resourceId
      }
    ]
    location: location1
    peerings: [
      {
        name: 'spoke3-to-cascaded-hub'
        remotePeeringName: 'cascaded-hub-to-spoke3'
        remoteVirtualNetworkResourceId: cascadedhubvnet.outputs.resourceId
        allowVirtualNetworkAccess: true
        allowForwardedTraffic: true
        remotePeeringEnabled: true
      }
    ]
  }
}
module ergw 'br/public:avm/res/network/virtual-network-gateway:0.10.0' = {
  name: 'egwDeployment'
  scope: rg
  params: {
    clusterSettings: {
      clusterMode: 'activePassiveBgp'
    }
    gatewayType: 'ExpressRoute'
    name: 'ergw'
    virtualNetworkResourceId: hubvnet.outputs.resourceId
    skuName: 'ErGw1AZ'
    allowRemoteVnetTraffic: true
  }
}
module c8k1 'csr.bicep' = {
  name: 'c8k-1vmDeployment'
  scope: rg
  params: {
    location: location1
    vmName: 'c8k-1'
    adminUser: adminUser
    adminPw: adminPw
    subnetId: hubvnet.outputs.subnetResourceIds[2] // Assuming third subnet is used
    c8kIPv4: c8k1IPv4

  }
}
module c8k2 'csr.bicep' = {
  name: 'c8k-2vmDeployment'
  scope: rg
  params: {
    location: location1
    vmName: 'c8k-2'
    adminUser: adminUser
    adminPw: adminPw
    subnetId: hubvnet.outputs.subnetResourceIds[2] // Assuming third subnet is used
    c8kIPv4: c8k2IPv4
  }
}

module arspubIPv4 'br/public:avm/res/network/public-ip-address:0.6.0' = {
  name: 'arsPublicIPv4Deployment'
  scope: rg
  params: {
    location: location1
    name: 'ars-public-ipv4'
    skuName: 'Standard'
    skuTier: 'Regional'
    publicIPAddressVersion: 'IPv4'
  }
}
module ars 'rs.bicep' = {
  name: 'routeServerDeployment'
  scope: rg
  params: {
    location: location1
    c8k1asn: 65010
    c8k2asn: 65020
    c8k1privateIPv4: c8k1.outputs.privateIPv4
    c8k2privateIPv4: c8k2.outputs.privateIPv4
    arssubnetId: hubvnet.outputs.subnetResourceIds[0] // Assuming first subnet is used
    arspubIpv4Id: arspubIPv4.outputs.resourceId
  }
}
module firewallpolicy 'br/public:avm/res/network/firewall-policy:0.3.3' = {
  name: 'firewallPolicyDeployment'
  scope: rg
  params: {
    name: 'azfw-policy'
    location: location1
    tier: 'Basic'
    threatIntelMode: 'Off'
    ruleCollectionGroups:[
      {
        name: 'RCG-1'
        priority: 100
        ruleCollections: [
          {
            name: 'RC-1'
            priority: 100
            action: {
              type: 'Allow'
            }
            rules: [
              {
                name: 'allow-any'
                ruleType: 'NetworkRule'
                destinationAddresses: [
                  '*'
                ]
                destinationPorts: [
                  '*'
                ]
                ipProtocols: [
                  'TCP'
                  'UDP'
                ]
                sourceAddresses: spokeAddressRanges
              }
            ]
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          }
        ]
      }
    ]
  }
}

module firewall 'br/public:avm/res/network/azure-firewall:0.9.1' = {
  name: 'azureFirewallDeployment'
  scope: rg
  params: {
    name: 'azfw'
    location: location1
    virtualNetworkResourceId: cascadedhubvnet.outputs.resourceId
    azureSkuTier: 'Basic'
    firewallPolicyId: firewallpolicy.outputs.resourceId
  }
}
module vmspoke1 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: 'spoke1-vm-deployment'
  scope: rg
  params: {
    location: location1
    name: 'spoke1-vm'
    adminUsername: adminUser
    adminPassword: adminPw
    availabilityZone: -1
    imageReference: {
      offer: '0001-com-ubuntu-server-jammy'
      publisher: 'Canonical'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            privateIPAddressVersion: 'IPv4'
            subnetResourceId: spoke1vnet.outputs.subnetResourceIds[0]
            privateIPAllocationMethod: 'Static'
            privateIPAddress: spoke1vmIPv4
          }
        ]
        nicSuffix: '-nic-01'
        enableAcceleratedNetworking: false
      }
    ]
    
    osDisk: {
      diskSizeGB: 30
      managedDisk: {
        storageAccountType: 'Standard_LRS'
      }
    }
    osType: 'Linux'
    vmSize: 'Standard_B1ms'
    bootDiagnostics: true
    // container image will be started via a VM extension module
  }
}
module vmspoke1ext 'vm-extension.bicep' = {
  name: 'spoke1-vm-extension-deployment'
  scope: rg
  params: {
    vmName: vmspoke1.outputs.name
    location: location1
    containerImage: containerImage
    containerPort: containerPort
    exposedPort: exposedPort
  }
}
module spokertable 'br/public:avm/res/network/route-table:0.5.0' = {
  name: 'spoke1-route-table-deployment'
  scope: rg
    params: {
    location: location1
    name: 'spoke1-rt'
    routes: [
      {
        name: 'default-route-to-azfw'
        properties: {
        addressPrefix: '0.0.0.0/0'
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: firewall.outputs.privateIp
        }
      }
    ]
  }
}
