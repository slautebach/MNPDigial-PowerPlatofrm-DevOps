
param(
    [string] $targetEnvironment = "dev-int",
    [string] $appId = "",
    [string] $clientSecret= "",
    [switch] $resetAuth
) 


# Load the Package Data
Import-Module "$PSScriptRoot\..\..\PS-Modules\Build-Package.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\..\..\PS-Modules\Dataverse-API.psm1" -Force -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation


SetPACConnections  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret  -resetAuth:$resetAuth

Write-Host "Build Package: $($PackageData.BuildPackagePath)"



# Get the list of packages enabled for build.
$buildPackages = $PackageData.BuildPackages

Write-Host "Environment: $targetEnvironment"

# If Solution Build is on, build the solution
if ($buildPackages.Solution ){
	Write-Host "******************************************************************************"
	Write-Host "*    Deploy Solution"
	Write-Host "******************************************************************************"
	. "$PSScriptRoot\Deploy-Solution.ps1" -targetEnvironment $targetEnvironment  -appId $appId -clientSecret $clientSecret 
}


if ($buildPackages.Data){
	Write-Host "******************************************************************************"
	Write-Host "*    Deploy Data"
	Write-Host "******************************************************************************"
	. "$PSScriptRoot\Deploy-Data.ps1" -targetEnvironment $targetEnvironment  -appId $appId -clientSecret $clientSecret 
}

if ($buildPackages.Portal ){
	Write-Host "******************************************************************************"
	Write-Host "*    Deploy Portal"
	Write-Host "******************************************************************************"
	. "$PSScriptRoot\Deploy-Portal.ps1" -targetEnvironment $targetEnvironment  -appId $appId -clientSecret $clientSecret 
}
