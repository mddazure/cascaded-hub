param location string = resourceGroup().location
param c8k1asn int
param c8k1privateIPv4 string
param c8k2asn int
param c8k2privateIPv4 string
param arssubnetId string
param arspubIpv4Id string

resource RouteServer 'Microsoft.Network/virtualHubs@2021-02-01' = {
  name: 'RouteServer'
  location: location
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: true
  }
}
resource rsIpConfig 'Microsoft.Network/virtualHubs/ipConfigurations@2021-02-01' ={
  name: 'rsIpConfig'
  parent: RouteServer
  dependsOn: [
    RouteServer
  ]
  properties:{
    subnet:{
      id: arssubnetId
    }
    publicIPAddress: {
      id: arspubIpv4Id
    }
  }
}
resource c8k1BgpConn 'Microsoft.Network/virtualHubs/bgpConnections@2021-02-01' = {
  name: 'c8k1BgpConn'
  dependsOn: [
    rsIpConfig
    RouteServer
    c8k2BgpConn
  ]
  parent: RouteServer

  properties: {
    peerAsn: c8k1asn
    peerIp: c8k1privateIPv4
  }
}
resource c8k2BgpConn 'Microsoft.Network/virtualHubs/bgpConnections@2021-02-01' = {
  name: 'c8k2BgpConn'
  dependsOn: [
    rsIpConfig
    RouteServer
  ]
  parent: RouteServer

  properties: {
    peerAsn: c8k2asn
    peerIp: c8k2privateIPv4
  }
}

