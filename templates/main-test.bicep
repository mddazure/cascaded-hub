param rgName string = 'cascaded-hub-rg-2'
param subscriptionId string = subscription().subscriptionId
param location1 string = 'swedencentral'

param testName string = 'test-vnet'
param testAddressPrefix string = '192.168.0.0/24'
param vmsubnetName string = 'VMSubnet'
param vmsubnetPrefix string = '192.168.0.0/26'
param gwsubnetName string = 'GatewaySubnet'
param gwsubnetPrefix string = '192.168.0.64/27'
param vmName string = 'vm-test'

// demo application container image
param containerImage string = 'madedroo/azure-region-viewer:latest'

//port backend vm's listen on
param exposedPort int = 80

//port exposed by the container
param containerPort int = 3000

param adminUser string = 'AzureAdmin'
param adminPw string = 'Cascaded-2025!'


targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: rgName
}

module vnet 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: 'vnetDeploy'
  scope: rg
  params: {
    location: location1
    name: testName
    addressPrefixes: [
      testAddressPrefix
    ]
    subnets: [
      {
        name: vmsubnetName
        addressPrefix: vmsubnetPrefix
      }
      {
        name: gwsubnetName
        addressPrefix: gwsubnetPrefix
      }
    ]
  }
}
module vmspoke1 'br/public:avm/res/compute/virtual-machine:0.20.0' = {
  name: 'spoke1-vm-deployment'
  scope: rg
  params: {
    location: location1
    name: vmName
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
            subnetResourceId: vnet.outputs.subnetResourceIds[0]
            privateIPAllocationMethod: 'Dynamic'
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
module ergw 'br/public:avm/res/network/virtual-network-gateway:0.10.0' = {
  name: 'egwDeployment'
  scope: rg
  params: {
    clusterSettings: {
      clusterMode: 'activePassiveBgp'
    }
    allowRemoteVnetTraffic: true
    gatewayType: 'ExpressRoute'
    name: 'testergw'
    virtualNetworkResourceId: vnet.outputs.resourceId
    skuName: 'ErGw1AZ'
  }
}
