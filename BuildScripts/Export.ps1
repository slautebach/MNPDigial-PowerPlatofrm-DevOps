param(
	[string] $targetEnvironment = "mnp-grants-standard", # Cloud Environment name (*.crm3.dynamics.com)
	[string] $appId = "", # optional app id to connect to dataverse
	[string] $clientSecret = "", #  client secret for the app id
	[switch] $all
) 

# Load build package info
Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking


ReInitializePACConnection  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret -tenant $PackageData.TenantId

$solutionName = $PackageData.SolutionName

Write-Host "Solution: $solutionName"

#***************************************************************************
#*   Extract Components
#***************************************************************************
cd "$PSScriptRoot\"

"$PSScriptRoot\UpdateBuildNumber.ps1" 

# Get the list of packages enabled for build.
$buildPackages = $PackageData.BuildPackages

Write-Host "Environment: $targetEnvironment"

# If Solution Build is on, build the solution
if ($buildPackages.Solution -or $all){
	Write-Host "******************************************************************************"
	Write-Host "*    Extracting Solution"
	Write-Host "******************************************************************************"
	. "$PSScriptRoot\Export-Solution.ps1" -targetEnvironment $targetEnvironment
}


if ($buildPackages.Portal -or $all){
	Write-Host "******************************************************************************"
	Write-Host "*    Extracting Portal"
	Write-Host "******************************************************************************"
	. "$PSScriptRoot\Export-Portal.ps1" -targetEnvironment $targetEnvironment
}

if ($buildPackages.Data -or $all){
	Write-Host "******************************************************************************"
	Write-Host "*    Extracting Data"
	Write-Host "******************************************************************************"
	. "$PSScriptRoot\Export-Data.ps1" -targetEnvironment $targetEnvironment
}