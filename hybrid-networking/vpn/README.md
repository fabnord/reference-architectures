# Connect an on-premises network to Azure using a VPN gateway

This reference architecture shows how to extend an on-premises network to Azure, using a site-to-site virtual private network (VPN). Traffic flows between the on-premises network and an Azure Virtual Network (VNet) through an IPSec VPN tunnel.

![](https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/images/vpn.png)

## Deploy the solution

For deployment instructions and guidance about best practices, see the article [Connect an on-premises network to Azure using a VPN gateway](https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/vpn) on the Azure Architecture Center.

The deployment uses [Azure Building Blocks](https://github.com/mspnp/template-building-blocks/wiki) (azbb), a command line tool that simplifies deployment of Azure resources.

### Prerequisites

1. Clone, fork, or download the zip file for the [reference architectures](https://github.com/mspnp/reference-architectures) GitHub repository.

2. Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest).

3. Install the [Azure building blocks](https://github.com/mspnp/template-building-blocks/wiki/Install-Azure-Building-Blocks) npm package.

   ```bash
   npm install -g @mspnp/azure-building-blocks
   ```

4. From a command prompt, bash prompt, or PowerShell prompt, sign into your Azure account as follows:

   ```bash
   az login
   ```

### Deploy resources

1. Navigate to the `/hybrid-networking/vpn` folder of the reference architectures GitHub repository.

2. Open the `hybrid-onprem.json` file. Search for instances of `AdminPassword`, `SafeModeAdminPassword` and `Password` and change values for the passwords.

3. Run the following command:

    ```bash
    azbb -s <subscription_id> -g <resource_group_name> -l <region> -p hybrid-onprem.json --deploy
    ```

4. Open the `hybrid-vpn.json` file. Search for instances of `AdminPassword`, `SafeModeAdminPassword` and `Password` and change values for the passwords.

5. Run the following command:

    ```bash
    azbb -s <subscription_id> -g <resource_group_name> -l <region> -p hybrid-vpn.json --deploy
    ```

### Connect the on-premises and Azure gateways

In this step, you will connect the two local network gateways.

1. In the Azure portal, navigate to the resource group that you created.

2. Find the resource named `ra-hybrid-vpn-vgw-pip` and copy the IP address shown in the **Overview** blade.

3. Find the resource named `ra-hybrid-onprem-lgw`.

4. Click the **Configuration** blade. Under **IP address**, paste in the IP address from step 2.

5. Click **Save** and wait for the operation to complete. It can take about 5 minutes.

6. Find the resource named `ra-hybrid-onprem-vgw-pip`. Copy the IP address shown in the **Overview** blade.

7. Find the resource named `ra-hybrid-vpn-lgw`.

8. Click the **Configuration** blade. Under **IP address**, paste in the IP address from step 6.

9. Click **Save** and wait for the operation to complete.

10. To verify the connection, go to the **Connections** blade for each gateway. The status should be **Connected**.

### Verify that network traffic reaches the web tier

1. In the Azure portal, navigate to the resource group that you created.

2. Find the resource named `ra-hybrid-vpn-web-lb`, which is the load balancer in front of the web servers. Copy the private IP address from the **Overview** blade.

3. Find the VM named `ra-hybrid-onprem-mgmt`. Click **Connect** and use Remote Desktop to connect to the VM. The user name and password are specified in the hybrid-onprem.json file.

4. From the Remote Desktop Session, open a web browser and navigate to the IP address from step 2. You should see the default iis home page.
