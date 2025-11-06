param vmName string
param adminUser string
@secure()
param adminPw string
param location string
param subnetId string
param c8kIPv4 string

resource nicPubIP 'Microsoft.Network/networkInterfaces@2020-08-01' = {
  name: '${vmName}-nic'
  location: location
  properties:{
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipv4config0'
        properties:{
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: subnetId
          }
          privateIPAddress: c8kIPv4
        }
      }
    ]
  }
}
resource vm 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmName
  location: location
  plan:{
    name: '17_13_01a-byol'
    publisher: 'cisco'
    product: 'cisco-c8000v-byol'
  }
  properties: {
    hardwareProfile:{
      vmSize: 'Standard_DS2_v2'
    }
    storageProfile:  {
      imageReference: {
        publisher: 'cisco'
        offer: 'cisco-c8000v-byol'
        sku: '17_13_01a-byol'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'      
        }
      }
      osProfile:{
        computerName: vmName
        adminUsername: adminUser
        adminPassword: adminPw
        linuxConfiguration: {
          patchSettings: {
            patchMode: 'ImageDefault'
          }
        }
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
      networkProfile: {
        networkInterfaces: [
        {
          id: nicPubIP.id
        }
      ]
    }
  }
}
output privateIPv4 string = nicPubIP.properties.ipConfigurations[0].properties.privateIPAddress

