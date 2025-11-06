targetScope = 'resourceGroup'

@description('Name of the VM to attach the extension to')
param vmName string
@description('Location for all resources.')
param location string 
@description('Container image to run')
param containerImage string
@description('Container port')
param containerPort int = 3000
param exposedPort int = 80

resource vmExt 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: '${vmName}/runDocker'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'sudo apt-get update -y && sudo apt-get install -y ca-certificates curl gnupg && sudo mkdir -p /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && sudo apt-get update -y && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && sudo systemctl enable docker && sudo systemctl start docker && sudo docker run -d --name azure-region-viewer --restart unless-stopped -p ${exposedPort}:${containerPort} ${containerImage}'
    }
  }
}
