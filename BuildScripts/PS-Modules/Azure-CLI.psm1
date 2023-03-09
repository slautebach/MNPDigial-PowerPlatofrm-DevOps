
if ($PSVersionTable.PSEdition -ne "Core"){
    throw "This module needs PS Core, please run your script from a version of PowerShell Core (ie PS 7)"
}

Import-Module "$PSScriptRoot\Functions.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot\Build-Package.psm1" -Force -DisableNameChecking
Load-PackageData


#This is installed for extracting the public key from the portal site in function: Get-PortalPublicKey
Write-Host "Install-Package -Name BouncyCastle.Cryptography -ProviderName NuGet -Scope CurrentUser -RequiredVersion 2.0.0 -SkipDependencies -Destination $PSScriptRoot -Force"
if(-Not (Test-Path -Path $PSScriptRoot\BouncyCastle.Cryptography.2.0.0))
{
    Install-Package -Name BouncyCastle.Cryptography -ProviderName NuGet -Scope CurrentUser -RequiredVersion 2.0.0 -SkipDependencies -Destination $PSScriptRoot -Force -Source "nuget.org"
}
[System.Reflection.Assembly]::LoadFrom("$PSScriptRoot\BouncyCastle.Cryptography.2.0.0\lib\net6.0\BouncyCastle.Cryptography.dll")

function Set-DataFactories([string]$resourceGroup, $dataFactories, $location = "canadacentral"){
    $existingDataFactories = az datafactory list --resource-group $resourceGroup | ConvertFrom-Json -AsHashtable

    foreach ($dataFactory in $dataFactories){
        $theDataFactory = $existingDataFactories | Where-Object { $_.name -eq $datafactory.name}
        if ($theDataFactory){
            Write-Host "Datafactory: $($datafactory.name), already exists"
        } else {
            Write-Host "Create Data Factory: $($datafactory.name)"
            Write-Host "                     $($datafactory.description)"
           $response =  az datafactory create `
              --factory-name $datafactory.name `
              --resource-group $resourceGroup `
              --location $location 

            if (!$response) {
                throw "Error Creating Data Factory"
            }

           $theDataFactory = $response  | ConvertFrom-Json -AsHashtable
        }
        Write-Host "     Name: $($theDataFactory.name)"
        Write-Host "       Id: $($theDataFactory.id)"
        Write-Host "-----------------------------"
    }
}


function Set-StorageAccounts([string]$resourceGroup, $storageAccounts, $location = "canadacentral"){
    $existingStorageAccounts = az storage account list --resource-group $resourceGroup | ConvertFrom-Json -AsHashtable

   
    foreach ($storageAccount in $storageAccounts){
        #strip out all "-" from the name
        $storageAccount.name = $storageAccount.name.Replace("-", "").ToLower()

        $theStorageAccount = $existingStorageAccounts | Where-Object { $_.name -eq $storageAccount.name}
        if ($theStorageAccount){
            Write-Host "Storage Account: $($storageAccount.name), already exists"
        } else {
            Write-Host "Create Data Factory: $($storageAccount.name)"
            Write-Host "                     $($storageAccount.description)"
            $response = az storage account create `
               -n $storageAccount.name `
               --resource-group $resourceGroup `
               --location $location        
            if (!$response) {
                throw "Error Creating Storage Account"
            }

            $theStorageAccount = $response  | ConvertFrom-Json -AsHashtable
        }
        Write-Host "     Name: $($theStorageAccount.name)"
        Write-Host "       Id: $($theStorageAccount.id)"
        Write-Host "-----------------------------"

        $existingContainers = az storage container list --account-name $theStorageAccount.name --auth-mode login | ConvertFrom-Json -AsHashtable
        foreach ($container in $storageAccount.containers){
            $theContainer = $existingContainers | Where-Object { $_.name -eq $container.name}
            if ($theContainer){
                Write-Host "Storage Container: $($container.name), already exists"
            } else {
                Write-Host "Create Storage Container: $($container.name)"
                $response = az storage container create `
                    --name "$($container.name)" `
                    --account-name "$($theStorageAccount.name)" `
                    --auth-mode login
                if (!$response) {
                    throw "Error Creating Container for Storage Account"
                }

                $theContainer = $response  | ConvertFrom-Json -AsHashtable
            }
            if ($container.access_level){
                Write-Host "Setting Public Access: $container.access_level"
                Write-Host "az storage container set-permission --name $($container.name) --account-name $($theStorageAccount.name) --public-access $($container.access_level) --auth-mode login"
                     $response = az storage container set-permission `
                        --name "$($container.name)" `
                        --account-name "$($theStorageAccount.name)" `
                        --public-access $container.access_level 2>nul               
                if (!$response) {
                     $response = az storage container set-permission `
                        --name "$($container.name)" `
                        --account-name "$($theStorageAccount.name)" `
                        --auth-mode login `
                        --public-access $container.access_level 
                }
                if (!$response) {
                    throw "Error setting container access level"
                }
            }
        }
    }
}


function Set-AppInsights([string]$resourceGroup, $appInsights, $sharedWorkspaces, $location = "canadacentral"){
    $existingAppInsights = az monitor app-insights component show --resource-group $resourceGroup | ConvertFrom-Json -AsHashtable

     foreach ($appInsight in $appInsights){
        $theAppInsight = $existingAppInsights | Where-Object { $_.name -eq $appInsight.name}
        if ($theAppInsight){
            Write-Host "App Insights: $($appInsight.name), already exists"
        } else {
            $workspace = $sharedWorkspaces  | Where-Object { $_.name -eq $appInsight.shared_workspacename}
            if ($workspace -eq $null){
                throw "Cannot Create App Insights, Shared Workspace: '$($appInsight.shared_workspacename)' doesn't exist."
            }
            Write-Host "Create App Insights: $($appInsight.name):"
            Write-Host "                     $($appInsight.description)"
            $response =  az monitor app-insights component create `
                --app $appInsight.name `
                --location $location `
                --kind web `
                --resource-group $resourceGroup `
                --application-type web `
                --workspace $workspace.id

            if (!$response) {
                throw "Error Creating App Insights"
            }
            $theAppInsight = $response  | ConvertFrom-Json -AsHashtable

        }
        Write-Host "     Name: $($theAppInsight.name)"
        Write-Host "       Id: $($theAppInsight.id)"
        Write-Host "-----------------------------"

    }
}


function Set-LogWorkspaces([string]$resourceGroup, $logAnalyticsWorkspaces, $location = "canadacentral"){
    $existingLogAnalyticsWorkspaces = az monitor log-analytics workspace list  --resource-group $resourceGroup | ConvertFrom-Json -AsHashtable
    
    foreach ($workspace in $logAnalyticsWorkspaces){
        $theWorkspace = $existingLogAnalyticsWorkspaces | Where-Object { $_.name -eq $workspace.name}
        if ($theWorkspace){
            Write-Host "Log Analytics Workspace: $($workspace.name), already exists"
        } else {
            Write-Host "Create Log Analytic Workspace: $($workspace.name):"
            Write-Host "                     $($workspace.description)"
            $response = az monitor log-analytics workspace create `
                --workspace-name $workspace.name `
                --resource-group $resourceGroup `
                --location $location
            if (!$response) {
                throw "Error Creating Log Workspace"
            }

            $theWorkspace = $response | ConvertFrom-Json -AsHashtable
        }
        Write-Host "     Name: $($theWorkspace.name)"
        Write-Host "       Id: $($theWorkspace.id)"
        Write-Host "-----------------------------"

    }
}

function Set-KeyVaults([string]$resourceGroup, $keyVaults, $location = "canadacentral"){
    $existingKeyValults = az keyvault list --resource-group $resourceGroup | ConvertFrom-Json -AsHashtable

     foreach ($keyvault in $keyVaults){
        $theKeyVault = $existingKeyValults | Where-Object { $_.name -eq $keyvault.name}
        if ($theKeyVault){
            Write-Host "Key Vault: $($keyvault.name), already exists"
        } else {
            Write-Host "Create Key Valut: $($keyvault.name):"
            Write-Host "                  $($keyvault.description)"
            $response = az keyvault create `
                --name $keyvault.name  `
                --resource-group $resourceGroup  `
                --location $location  `
                --enabled-for-template-deployment true

            if (!$response) {
                throw "Error Creating Key Vault"
            }


            $theKeyVault = $response | ConvertFrom-Json -AsHashtable 
        }
        Write-Host "     Name: $($theKeyVault.name)"
        Write-Host "       Id: $($theKeyVault.id)"
        Write-Host "-----------------------------"

        foreach ($keyType in @('key', 'secret', 'certificate')){
            Write-Host "     Processing KeyValuts type: $keyType"
            $keys = $keyvault."$($keyType)s"
            
            foreach ($key in $keys){
                $keyName = $($key.name)
                $keyValue = $key.value
                if (!$keyValue){
                    Write-Warning "     --Key: $keyName, is not set."
                    $keyValue = "NOT SET"                    
                }
                Write-Host "          Setting $($keyType): $($key.name)"
                $response = az keyvault $keyType set --name $keyName --value $keyValue --vault-name $keyvault.name

                if (!$response) {
                    throw "Error Adding Key: $keyName"
                }
                $theKey = $response| ConvertFrom-Json -AsHashtable
            }
        }
    }
}

function Set-AppServicePlans([string]$resourceGroup, $appServicePlans, $location = "canadacentral"){
    $existingAppServicePlans = az appservice plan list --resource-group $resourceGroup | ConvertFrom-Json -AsHashtable
    foreach ($plan in $appServicePlans){
        $thePlan = $existingAppServicePlans | Where-Object { $_.name -eq $plan.name}
        if ($thePlan){
            Write-Host "App Service Plan : $($plan.name), already exists"
        } else {
            Write-Host "Create App Service Plan: $($plan.name)"
            Write-Host "            description: $($plan.description)"

           
            $response = az appservice plan create `
                --name $plan.name `
                --resource-group $resourceGroup `
                --sku $plan.sku `
                --location $location
            if (!$response) {
                throw "Error Creating App Service Plan"
            }

            $thePlan = $response | ConvertFrom-Json -AsHashtable
        }
        Write-Host "     Name: $($thePlan.name)"
        Write-Host "       Id: $($thePlan.id)"
        Write-Host "-----------------------------"
    }
}

function Set-FunctionApps([string]$resourceGroup, $functionApps , [string]$sharedEnvironmentGroup, $location = "canadacentral"){

    $existingFunctionApps = az functionapp list  --resource-group $resourceGroup | ConvertFrom-Json -AsHashtable
    
    foreach ($fApp in $functionApps)
    {
        $theFApp = $existingFunctionApps | Where-Object { $_.name -eq $fApp.name}
        $fApp.storageaccount = $fApp.storageaccount.Replace("-", "").ToLower()
        if ($theFApp){
            Write-Host "Function App : $($fApp.name), already exists"
        } else {
            Write-Host "Create Function App: $($fApp.name)"
            Write-Host "        description: $($fApp.description)"
            Write-Host "    stroage account: $($fApp.storageaccount)"

            
            if($fApp.plan){
                $response = az functionapp create `
                --name $fApp.name `
                --resource-group $resourceGroup `
                --storage-account $fApp.storageaccount `
                --os-type $fApp.ostype `
                --runtime $fApp.runtime `
                --runtime-version $fApp.runtimeVersion `
                --functions-version $fApp.functionversion `
                --consumption-plan-location $location `
                --plan $($fApp.plan)
            }
            else {
                $response = az functionapp create `
                --name $fApp.name `
                --resource-group $resourceGroup `
                --storage-account $fApp.storageaccount `
                --os-type $fApp.ostype `
                --runtime $fApp.runtime `
                --runtime-version $fApp.runtimeVersion `
                --functions-version $fApp.functionversion `
                --consumption-plan-location $location
            }

            

            if (!$response) {
                throw "Error Creating Function App"
            }

            $theFApp = $response | ConvertFrom-Json -AsHashtable
        }

        Write-Host "     Name: $($theFApp.name)"
        Write-Host "       Id: $($theFApp.id)"
        Write-Host "-----------------------------"

        #Update/Set the settings.
        $appsettings = $fApp.settings
      
        Write-Host " az functionapp config appsettings set -g $resourceGroup -n $($fApp.name) --settings $appsettings"
        $response = az functionapp config appsettings set -g $resourceGroup -n $fApp.name --settings @appsettings

        #update Set the Identity and attach to vault
        $response = az functionapp identity assign -g $resourceGroup -n $fApp.name
        $response=$response | ConvertFrom-Json -AsHashtable
        
        Set-KeyVaultPolicy -sharedEnvironmentGroup $sharedEnvironmentGroup -principalId $response.principalId

        
        # Check if the artificat exists in the build directory then deploy it
        $packageFolder = $PackageData.BuildPackagePath

        $zipPackage = "$packageFolder\$($fApp.artifactName)"

        Write-Host "Checking for Artifact $zipPackage"
        if(Test-Path $zipPackage -PathType Leaf)
        {
            Write-Host "Artifact found for $($fApp.name) deploying"
            # Deploy the packaged zip function to the resource
            DeployFunctionApp -resourceGroup $resourceGroup -functionAppName $fApp.name -zipPackage $zipPackage
        }
    }
}

function Set-ApiMs([string]$resourceGroup, $apims, $location = "canadacentral"){
    $existingApims = az apim list  --resource-group $resourceGroup | ConvertFrom-Json -AsHashtable
    
    foreach ($apim in $apims){
        $theApim = $existingApims | Where-Object { $_.name -eq $apim.name}
        if ($theApim){
            Write-Host "API Management : $($theApim.name), already exists"
        } else {
            $publisherEmail = $apim.publisheremail
            if (!$publisherEmail){
                $publisherEmail = "email@mailinator.com"
            }

            $publisherName = $apim.publishername
            Write-Host "Create API Management: $($apim.name):"
            Write-Host "          description: $($apim.description)"
            Write-Host "      Publisher Email: $publisherEmail"
            Write-Host "       Publisher Name: $publisherName"
            $response = az apim create `
                --name $apim.name `
                --resource-group $resourceGroup `
                --publisher-email  $publisherEmail `
                --publisher-name  $publisherName `
                --location $location `
                --sku-name Consumption
            if(!$response){
                throw "Unble to create $($apim.name)"
            }
            $theApim = $response | ConvertFrom-Json -AsHashtable
            
        }
        Write-Host "     Name: $($theApim.name)"
        Write-Host "       Id: $($theApim.id)"
        Write-Host "-----------------------------"

        
        #get subscription of APIM
        Write-Host "az apim show -n $($theApim.name) -g $resourceGroup --query id -o tsv"
        $APIMID=az apim show -n "$($theApim.name)" -g "$resourceGroup" --query id -o tsv
        
        Write-Host "Create/Update Named Values"
        #Create/Update Named Values
        $apimNamedValues = $apim.named_values
        foreach ($apimNamedValue in $apimNamedValues){
            Write-Host "$($apimNamedValue)"
            az rest --method PUT --url "$($APIMID)/namedValues/$($apimNamedValue.displayName)?api-version=2021-08-01" --body "{'properties': {'displayName': '$($apimNamedValue.displayName)','secret':$($apimNamedValue.secret),'value': '$($apimNamedValue.value)'}}"
        }

        Write-Host "Create/Update global policies"
        #Create/Update global policies
        
        if($apim.globalPolicyFile)
        {
            [xml]$policyXml = Get-Content -Encoding utf8 "$PSScriptRoot\..\DeployScripts\Azure-Resources\$($apim.globalPolicyFile)"
            $policyXmlString =  ($policyXml.InnerXml)  -replace "`"", "\'"
            $uri ="$($APIMID)/policies/policy?api-version=2021-08-01"
            $body = "{'properties':{'method': 'PUT','value':'$policyXmlString','format':'rawxml'}}"
            Write-Host "az rest --method PUT --uri $uri --body $body"
            $response = az rest --method PUT --uri $uri --body $body
        }
        
        #Delete existing APIs
        $existingAPIList = az apim api list --resource-group $resourceGroup --service-name $($apim.name) --query [*].name -o tsv
        foreach ($existingAPI in $existingAPIList){
            Write-Host "Deleting $existingAPI"
            $response = az apim api delete --resource-group $resourceGroup --service-name "$($theApim.name)" --api-id $existingAPI -y
        }

        #import resources
        foreach ($importResource in $apim.importResources) {
            # check if it exists before importing
             Write-Host "az apim api import --resource-group $resourceGroup --service-name $($theApim.name) --path $($importResource.apiURLSuffix) --specification-format Swagger --specification-url https://$($($importResource.name)).azurewebsites.net/api/swagger.json -o json"
            $newAPI = az apim api import --resource-group $resourceGroup --service-name "$($theApim.name)" --path "$($importResource.apiURLSuffix)" --specification-format Swagger --specification-url "https://$($($importResource.name)).azurewebsites.net/api/swagger.json" -o json

            if($newAPI){
                $newAPI = $newAPI | ConvertFrom-Json
                $newApiId = $newAPI[0].id

                $functionAppKeys = az functionapp keys list --resource-group $resourceGroup --name $($importResource.name) -o json
                $functionAppKeys = $functionAppKeys | ConvertFrom-Json -AsHashtable
                $functionAppDefaultKey = $functionAppKeys.functionKeys.default
                if($importResource.policyFile)
                {
                    [xml]$policyXml = Get-Content -Encoding utf8 "$PSScriptRoot\..\DeployScripts\Azure-Resources\$($importResource.policyFile)"

                    $defaultKeyElement = $policyXml.SelectSingleNode('policies/inbound/set-query-parameter/value')
                    $defaultKeyElement.InnerText = "$functionAppDefaultKey"

                    $policyXmlString =  ($policyXml.InnerXml)  -replace "`"", "\'"
                    $uri ="$($newApiId)/policies/policy?api-version=2021-08-01"
                    $body = "{'properties':{'method': 'PUT','value':'$policyXmlString','format':'rawxml'}}"
                    Write-Host "az rest --method PUT --uri $uri --body $body --output-file policyTempOutput.log"
                    $response = az rest --method PUT --uri $uri --body $body --output-file policyTempOutput.log
                    Remove-Item policyTempOutput.log -Force  -ErrorAction SilentlyContinue

                }
            }

        }
        
    }
    Write-Host "Set-ApiMs Completed"
}

function Set-Resources([string]$resourceGroup, $sharedEnvironmentGroup, $parameters, $location = "canadacentral", [switch] $ignoreUnsupportedResourceTypes){
    $existingSharedWorkspaces = @()
    Write-Host "Shared Resoruce Group: $sharedResourceGroup"
    if ($sharedResourceGroup -ne ""){
        $existingSharedWorkspaces = az monitor log-analytics workspace list  --resource-group $sharedResourceGroup | ConvertFrom-Json -AsHashtable
    }
    $parameters.PSObject.Properties | ForEach-Object {         
        $resourceType = $_.Name
        $resources = $_.Value
        switch ($resourceType){
           "datafactories" {
                Write-Host ""
                Write-Host ""
                Write-Host "##################################################################################################"
                Write-Host "#  Processing Azure Data Factories "
                Write-Host "##################################################################################################"

                Set-DataFactories -resourceGroup $resourceGroup -dataFactories $resources -location $location
                break;
            }
            "storageaccounts" {
                Write-Host ""
                Write-Host ""
                Write-Host "##################################################################################################"
                Write-Host "#  Processing Storage Accounts "
                Write-Host "##################################################################################################"

                Set-StorageAccounts -resourceGroup $resourceGroup -storageAccounts $resources -location $location
                break;
            }
            "appinsights" {
                Write-Host ""
                Write-Host ""
                Write-Host "##################################################################################################"
                Write-Host "#  Processing App Insights "
                Write-Host "##################################################################################################"
                Set-AppInsights -resourceGroup $resourceGroup -appInsights $resources -sharedWorkspaces $existingSharedWorkspaces -location $location
                break;
            }
            "logworkspaces" {
                Write-Host ""
                Write-Host ""
                Write-Host "##################################################################################################"
                Write-Host "#  Processing Log Workspaces "
                Write-Host "##################################################################################################"
                Set-LogWorkspaces -resourceGroup $resourceGroup -logAnalyticsWorkspaces  $resources -location $location
                break;
            }
            "keyvaults" {
                Write-Host ""
                Write-Host ""
                Write-Host "##################################################################################################"
                Write-Host "#  Processing Key Valuts "
                Write-Host "##################################################################################################"
                Set-KeyVaults -resourceGroup $resourceGroup -keyVaults  $resources -location $location
                break;
            } 
            "appserviceplans" {
                Write-Host ""
                Write-Host ""
                Write-Host "##################################################################################################"
                Write-Host "#  Processing App Service Plans "
                Write-Host "##################################################################################################"
                Set-AppServicePlans -resourceGroup $resourceGroup -appServicePlans  $resources -location  $location 
                break;
            }
            "functionapps" {
                Write-Host ""
                Write-Host ""
                Write-Host "##################################################################################################"
                Write-Host "#  Processing Function Apps "
                Write-Host "##################################################################################################"
                Set-FunctionApps -resourceGroup $resourceGroup -functionApps  $resources -sharedEnvironmentGroup $sharedEnvironmentGroup
                break;
            }
            "apims" {
                Write-Host ""
                Write-Host ""
                Write-Host "##################################################################################################"
                Write-Host "#  Processing API Managements "
                Write-Host "##################################################################################################"
                Set-ApiMs -resourceGroup $resourceGroup -apims  $resources -location $location
                break;
            }
            default {
                Write-Host ""
                Write-Host ""
                Write-Host "##################################################################################################"
                if ($ignoreUnsupportedResourceTypes){ 
                    Write-Host "#  Unable to create resoruces of type: $resourceType, not supported "
                    Write-Host "##################################################################################################"
                } else {
                    throw "Unable to create resoruces of type: $resourceType, not supported"
                }
                break;
            }
        }
    }
}

function DeployFunctionApp([string]$resourceGroup, [string] $functionAppName, [string] $zipPackage){
    Write-Host " az functionapp deployment source config-zip -g $resourceGroup -n $functionAppName --src $zipPackage"
    $response = az functionapp deployment source config-zip -g $resourceGroup -n $functionAppName --src $zipPackage
}


function Set-KeyVaultPolicy([string]$sharedEnvironmentGroup, [string] $principalId){
    Write-Host " az keyvault set-policy -n cloud-$sharedEnvironmentGroup --key-permissions get list --secret-permissions  get list --certificate-permissions get list --object-id $principalId"
    $response = az keyvault set-policy -n cloud-$sharedEnvironmentGroup --key-permissions get list --secret-permissions  get list --certificate-permissions get list --object-id $principalId
}

function Get-PortalPublicKey($targetEnvironment) {

    Write-Host "Getting public key from: https://$($targetEnvironment).powerappsportals.com/_services/auth/publickey" 
    $portalResponse =  invoke-webrequest "https://$($targetEnvironment).powerappsportals.com/_services/auth/publickey" 
    if($portalResponse -like '-----BEGIN PUBLIC KEY-----*'){
        $reader = New-Object -TypeName System.IO.StringReader -ArgumentList $portalResponse
        $x = New-Object Org.BouncyCastle.OpenSsl.PemReader($reader)
        $y = [Org.BouncyCastle.Crypto.Parameters.RsaKeyParameters] $x.ReadObject()
        return @{"Modulus" = $([System.Convert]::ToBase64String($y.Modulus.ToByteArrayUnsigned())); "Exponent" = $([System.Convert]::ToBase64String($y.Exponent.ToByteArrayUnsigned()))}
    }
    else
    {
        return @{"Modulus" = "NO_KEY"; "Exponent" = "NO_KEY"}
    }
}

Export-ModuleMember -Function * -Alias * -WarningAction SilentlyContinue 

