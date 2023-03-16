param(
	[Parameter(Mandatory=$true)]
    [string]$targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
	[string]$appId = "", # optional app id to connect to dataverse
	[string]$clientSecret = "", #  client secret for the app id
	[switch]$unmanaged # specifies to deploy the unmanaged solution
) 

Import-Module "$PSScriptRoot\..\..\PS-Modules\Extract-Solution-Components.psm1" -Force  -DisableNameChecking
Import-Module "$PSScriptRoot\..\..\PS-Modules\Build-Package.psm1" -Force -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

SetPACConnections  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret -logConfig

Write-Host ""
Write-Host "=================================================================="
Write-Host "Connecting to Dataverse API for N52 validation"
Write-Host "=================================================================="
ConnectDataverseApi  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret

$solutionName = $PackageData.SolutionName

if ($unmanaged){
	#Constants
	$solutionZipFile = "$($PackageData.BuildPackagePath)\$($solutionName)_unmanaged.zip"
} else {
	#Constants
	$solutionZipFile = "$($PackageData.BuildPackagePath)\$($solutionName)_managed.zip"
}

Write-Host "Deploying Solution Zip to: $solutionZipFile"
ImportSolution -solutionZipFile $solutionZipFile -unmanaged:$unmanaged