# **Cascaded Hub & Spoke Foundation**  

The VNET-based hub & spoke network foundation recommended by the [Cloud Aoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/traditional-azure-networking-topology) consists of a hub VNET containing a VNET Gateway connected to an Expressroute circuit and a security device, and directly peered spoke VNETs. The spoke VNET's prefixes are routable from the hub VNET via the VNET peers, and are advertised over BGP by the Expressroute Gateway to Microsoft Enterprise Edge (MSEE) routers that terminate the Expressroute cicruit. The MSEE routers in turn advertise these prefixes to the on premise routers and VMs in the spoke prefixes are reachable from on premise.

Some customers choose to implement a "cascaded hub" model, where an intermediate VNET sits between the hub- and spoke VNETs. VNET peering is "non-transitive", meaning that the spoke VNET's prefixes are now not routeable from the hub VNET, and are not advertised by the Expressroute Gateway to the MSEE routers. The MSEE routers nor the on premise routers have a route to the spoke prefixes, so that the spokes are now unreachable from on premise.

A solution to thsi problem is to inject the spoke VNET prefixes into the Expressroute Gateway. This requires Azure Route Server (ARS), which the element in Azure that provides a BGP interface to the Azure routing plane, and a Network Virtual Appliance to originate and inject the spoke prefixes into ARS (ARS itself does not have the ability to originate routes).

This lab demonstrates how to build a "cascaded hub" hub & spoke network foundation using ARS and the Cisco 8000v NVA.

![image](/images/cascaded-hub.png)


