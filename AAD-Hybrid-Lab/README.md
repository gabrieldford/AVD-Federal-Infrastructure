# Azure Active Directory Hybrid Lab

## Creates an AD VM with Azure AD Connect installed

## Quick Start

[![Deploy to Azure Commercial](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawntmeyer%2FAVDFedRockstarTraining%2Fmain%2F%2FAAD-Hybrid-Lab%2Fdeploy.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawntmeyer%2FAVDFedRockstarTraining%2Fmain%2F%2FAAD-Hybrid-Lab%2FuiDefinition.json)
[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawntmeyer%2FAVDFedRockstarTraining%2Fmain%2F%2FAAD-Hybrid-Lab%2Fdeploy.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fshawntmeyer%2FAVDFedRockstarTraining%2Fmain%2F%2FAAD-Hybrid-Lab%2FuiDefinition.json)

## Details

* Requires a Virtual Network and Subnet
* Deploys the following infrastructure:
  * VM with Active Directory Domain Services and DNS Role
  * DSC installs AD
    * Test users are created
    * Azure Active Directory Connect is installed and available to configure.

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
