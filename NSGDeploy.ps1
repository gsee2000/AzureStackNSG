# Pre requisites - working ARM template JSON file, working ARM template JSON peramaters file, latest NSG VHD

# Variables required
# Login Variables
$AADTenantName = "company.com"
$ArmEndpoint = "https://management.location.azure.company.com"
$environmentname = "AzureStackUser"

# AzureStack user environment variables
$resourceGroupName = "NSGDeploy01"
$accountName = "nsgimage"
$location = "location"
$skuname = "Standard_LRS"
# Prefix 'vm' taken from what has been specified in ARM Template vmName field
$vmname = 'vm' + $resourceGroupName

# Image variables
$urlOfUploadedVhd = "https://nsgimage.blob.location.azure.company.com/nsgrun01/nsg-5.2.2.vhd"
$localfilepath = "C:\NSGVHD\nsg-5.2.2.vhd"
$CustomTemplateJSON = "C:\NSGARM\nsgdualnic.json"
$CustomTemplateParamJSON = "C:\NSGARM\nsg.parameters.json"

# Register an Azure Resource Manager environment that targets your Azure Stack instance
Add-AzureRMEnvironment `
  -Name "AzureStackUser" `
  -ArmEndpoint $ArmEndpoint

$AuthEndpoint = (Get-AzureRmEnvironment -Name "AzureStackUser").ActiveDirectoryAuthority.TrimEnd('/')
$TenantId = (invoke-restmethod "$($AuthEndpoint)/$($AADTenantName)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]

# Sign in to your environment
Login-AzureRmAccount -EnvironmentName $environmentname -TenantId $TenantId

#Create ResourceGroup
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location

# Create blob endpoint ready to receive NSG VHD upload
$blobEndpoint = (New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $accountName -Location $location -SkuName $skuname).PrimaryEndpoints.Blob

# Upload VHD to blob endpoint
Add-AzureRmVhd -ResourceGroupName $resourceGroupName -Destination $urlOfUploadedVhd -LocalFilePath $localfilepath

# Ensure Template is valid is returned
Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $CustomTemplateJSON -TemplateParameterFile $CustomTemplateParamJSON -Verbose

# Deploy NSG
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $CustomTemplateJSON -TemplateParameterFile $CustomTemplateParamJSON –Verbose

# Check VM is powered on and running
$status = (Get-AzureRmVM -Name $vmname -ResourceGroupName $resourceGroupName -Status)
$status.statuses | select DisplayStatus

# Obtain NSG public IP
$PublicIP = (Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName)
$PublicIP.ipaddress

# SSH string to use to connect to deployed NSG
$sshString = 'ssh nuage@' + $publicIP.ipaddress + ' -p 893'
$sshString #paste this into an SSH client if your version of Windows/Powershell does not have SSH
invoke-expression $sshString



# Power on VM
# Start-AzureRmVM -Name $vmname -ResourceGroupName $ResourceGroupName
# Stop-AzureRmVM -Name $vmname -ResourceGroupName $ResourceGroupName
