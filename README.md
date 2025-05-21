# Azure Virtual Desktop Lab Landing Zone

## Federal Testing

I am using this code to deploy AVD infrasture to the Federal environment. This does not do the AVD it only does the infrastructure. I need to delete the quick start.

## Quick Start

[![Deploy to Azure Commercial](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawntmeyer%2FAVDFedRockstarTraining%2Fmain%2Fdeploy.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawntmeyer%2FAVDFedRockstarTraining%2Fmain%2FuiFormDefinition.json)

## Details

* Deploys the following infrastructure:
  * Hub Virtual Network with Azure Firewall, Firewall Policies for ADDS and AVD, Bastion, and associated subnets
  * Private DNS Zones for all the private DNS zones required to support AVD.
  * ADDS Spoke Virtual Network peered to Hub with Route Table to force default route through Firewall. Additionally deploys network security group to protect ADDS subnet.
  * VM with Active Directory Domain Services and DNS Role
  * DSC installs AD
    * Test users are created
    * Azure Active Directory Connect is installed and available to configure.
  * AVD Spoke Virtual Network peered to Hub with Route Table to force default route through Firewall. Additionally deploys network security group to protect AVD session hosts.

## NOTICE/WARNING

* This template is explicitly designed for a lab/classroom environment. A few compromises were made, especially with regards to credential passing to DSC, that WILL result in clear text passwords being left behind in the DSC package folders, Azure log folders, and system event logs on the resulting VMs.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
