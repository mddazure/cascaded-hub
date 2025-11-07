# **Cascaded Hub & Spoke Foundation**  

The VNET-based hub & spoke network foundation recommended by the [Cloud Aoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/traditional-azure-networking-topology), consists of a hub VNET containing a VNET Gateway connected to an Expressroute circuit and a security device, and **directly** peered spoke VNETs. The spoke VNET's prefixes are routable from the hub VNET via the VNET peers, and are advertised over BGP by the Expressroute Gateway to Microsoft Enterprise Edge (MSEE) routers that terminate the Expressroute cicruit. The MSEE routers in turn advertise these prefixes to the on premise routers and VMs in the spoke prefixes are reachable from on premise.

Some customers choose to implement a "cascaded hub" model, where an intermediate VNET sits between the hub- and spoke VNETs. VNET peering is "non-transitive", meaning that the spoke VNET's prefixes are now not routeable from the hub VNET, and are not advertised by the Expressroute Gateway to the MSEE routers. The MSEE routers nor the on premise routers have a route to the spoke prefixes, so that the spokes are now unreachable from on premise.

A solution to thsi problem is to inject the spoke VNET prefixes into the Expressroute Gateway. This requires Azure Route Server (ARS), which the element in Azure that provides a BGP interface to the Azure routing plane, and a Network Virtual Appliance to originate and inject the spoke prefixes into ARS (ARS itself does not have the ability to originate routes).

This lab demonstrates how to build a "cascaded hub" hub & spoke network foundation using ARS and the Cisco 8000v NVA.

![image](/images/cascaded-hub.png)

# Deploy
Log in to Azure Cloud Shell at https://shell.azure.com/ and select Bash.

Ensure Azure CLI and extensions are up to date:
  
      az upgrade --yes
  
If necessary select your target subscription:
  
      az account set --subscription <Name or ID of subscription>
  
Clone the  GitHub repository:
  
      git clone hhttps://github.com/mddazure/cascaded-hub
  
Change directory:
  
      cd ./cascaded-hub

Accept the terms for the CSR8000v Marketplace offer:

      az vm image terms accept -p cisco -f cisco-c8000v-byol --plan 17_13_01a-byol -o none

Deploy the Bicep template:

      az deployment sub create --location swedencentral --template-file templates/main.bicep

Verify that all components in the diagram above have been deployed to the resourcegroup `cascaded-hub-rg-2` and are healthy. 

Credentials:

username: `AzureAdmin`

password: `Cascaded-2025!`

# Configure
Both CSR 8000v NVA's are up but must still be configured.

Log in to the each NVA, preferably via the Serial console in the portal as this does not rely on network connectivity in the VNET. 
  - Serial console is under Support + troubleshooting in the Virtual Machine blade.

Enter credentials.

Enter Enable mode by typing `en` at the prompt, then enter Configuration mode by typing `conf t`. Paste in the below commands:

      license boot level network-advantage addon dna-advantage
      do wr mem
      do reload

The NVA will now reboot. When rebooting is complete log on again through Serial Console. Enter Enable mode by typing `en` at the prompt, then enter Configuration mode by typing `conf t`.

Copy and paste the configuration from the files c8k1.ios and c8k2.ios, located in the templates folder, into c8k1 and c8k2 respectively.

Type `end` to exit configuration mode and type `copy run start` to store the configuration.

# Observe
Both oth Cicso C8000v NVA's have BGP neighbors configured with both endpoints of ARS:
```
router bgp 65010
 bgp log-neighbor-changes
 ...
 neighbor 10.0.0.68 remote-as 65515
 neighbor 10.0.0.68 ebgp-multihop 255
 ...
 neighbor 10.0.0.69 remote-as 65515
 neighbor 10.0.0.69 ebgp-multihop 255
```

Both NVA's have a static route configured for the supernet of the spoke prefixes, 172.16.0.0/12, and BGP is configured to redistribute static routes:
```
! static route to spoke VNets address space pointing to CSR subnet default gateway
ip route 172.16.0.0 255.240.0.0 GigabitEthernet1 10.0.0.1

router bgp 65010
 bgp log-neighbor-changes
! let bgp redistribute static routes to ARS
 redistribute static 
 ...
```

A route map sets the Nexthop IP BGP property to the address of the Azure Firewall in the cascaded hub, 10.0.1.68. This route map is applied to the BGP neighbors in the outbound direction:
```
ip access-list standard 10
 10 permit 172.16.0.0 0.15.255.255
!
! route-map to set next-hop for spoke routes to the Azure Firewall address
route-map SET_NEXTHOP_TO_SPOKES permit 10 
 match ip address 10
 set ip next-hop 10.0.1.68

router bgp 65010
...
 neighbor 10.0.0.68 route-map SET_NEXTHOP_TO_SPOKES out
...
 neighbor 10.0.0.69 route-map SET_NEXTHOP_TO_SPOKES out
```

This results in ARS learning the spoke supernet with the address of the firewall as the next hop from both NVA's:

```
az network routeserver peering list-learned-routes -g cascaded-hub-rg-2 --routeserver RouteServer -n c8k1BgpConn
{
  "RouteServiceRole_IN_0": [
    {
      "asPath": "65010",
      "localAddress": "10.0.0.68",
      "network": "172.16.0.0/12",
      "nextHop": "10.0.1.68",
      "origin": "EBgp",
      "sourcePeer": "10.0.0.132",
      "weight": 32768
    }
  ],
  "RouteServiceRole_IN_1": [
    {
      "asPath": "65010",
      "localAddress": "10.0.0.69",
      "network": "172.16.0.0/12",
      "nextHop": "10.0.1.68",
      "origin": "EBgp",
      "sourcePeer": "10.0.0.132",
      "weight": 32768
    }
  ]
}

az network routeserver peering list-learned-routes -g cascaded-hub-rg-2 --routeserver RouteServer -n c8k2BgpConn
{
  "RouteServiceRole_IN_0": [
    {
      "asPath": "65020",
      "localAddress": "10.0.0.68",
      "network": "172.16.0.0/12",
      "nextHop": "10.0.1.68",
      "origin": "EBgp",
      "sourcePeer": "10.0.0.133",
      "weight": 32768
    }
  ],
  "RouteServiceRole_IN_1": [
    {
      "asPath": "65020",
      "localAddress": "10.0.0.69",
      "network": "172.16.0.0/12",
      "nextHop": "10.0.1.68",
      "origin": "EBgp",
      "sourcePeer": "10.0.0.133",
      "weight": 32768
    }
  ]
}
```
Inspecting the Expressroute cicruit's route table shows that the spoke supernet is advertised:

![image](/images/lab-er-rt.png)

Note that only the spoke supernet learned from c8k-1 (AS 65010) is advertised to and installed in the circuit's route table. This is normal BGP behavior.

When c8k-1 is turned off, the route learned from c8k-2 appears in the circuit's route table. This demonstrates high availability of the route injectiion mechanism with a pair NVA's:

```
az network routeserver peering list-learned-routes -g cascaded-hub-rg-2 --routeserver RouteServer -n c8k1BgpConn
{
  "RouteServiceRole_IN_0": [],
  "RouteServiceRole_IN_1": []
}
```
![image](/images/lab-er-rt-c8k2.png)

A test VNET connected via a seperate Expressroute circuit to the same Megaport Cloud Router (MCR) instance as the lab circuit, is used to simulate an on premise location.

![image](/images/test-vnet.png)

The route table of the Expressroute cicruit connected to the test VNET also has the spoke supernet:

![image](/images/test-er-rt.png)

The end result is that a vm in spoke1 vnet, at 172.16.1.4, can reach a vm in the simulated on premise network at 192.168.0.4:

![image](/images/pingspoke1.png)

Traffic flows through the firewall and shows in the firewall logs:

![image](/images/fw-log.png)

Traffic does not flow through the NVA's as is demonstrated by traceroute:

![image](/images/tracert.png)





