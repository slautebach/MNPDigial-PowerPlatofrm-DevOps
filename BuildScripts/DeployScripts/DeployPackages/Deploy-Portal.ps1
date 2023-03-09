param(
	[Parameter(Mandatory=$true)]
	[string]$targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
	[string]$appId = "", # optional app id to connect to dataverse
	[string]$clientSecret = "", #  client secret for the app id
	[string]$rootPortalPath = ""
) 


Import-Module "$PSScriptRoot\..\..\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

Load-PackageData

SetPACConnections  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret -resetAuth


#Constants
$portalZip = "$($PackageData.BuildPackagePath)\$($PackageData.PortalName).zip"
# use a short path 'p' to prevent long file names
$portalExtractPath = "$($PackageData.BuildPackagePath)\p\"

#if we are on a build server, set the portal extract path to the default working directory
if ($env:SYSTEM_DEFAULTWORKINGDIRECTORY){
	$portalExtractPath = "$($env:SYSTEM_DEFAULTWORKINGDIRECTORY)\p\"
}

Write-Host "Removing $portalExtractPath"
Remove-Item -Force -ErrorAction SilentlyContinue -Recurse $portalExtractPath
mkdir $portalExtractPath | Out-Null

Write-Host " Extracting Portal to Path: $portalExtractPath"
Write-Host Expand-Archive -Path $portalZip -DestinationPath $portalExtractPath

Expand-Archive -Path $portalZip -DestinationPath $portalExtractPath

$LastExitCode = 0

Write-Host "Uploading Portal from: $portalExtractPath to $targetEnvironment"
if (Test-Path -Path "$portalExtractPath\deployment-profiles\profile.deployment.yml"){
	Write-Host "Creating Deployment Profile for $targetEnvironment"
	ReplaceEnvVariables -inFile "$portalExtractPath\deployment-profiles\profile.deployment.yml" -outFile "$portalExtractPath\deployment-profiles\$targetEnvironment.deployment.yml"
	pac paportal upload --path "$portalExtractPath" --deploymentProfile $targetEnvironment
} else {
	Write-Host "Not Using Deployment a Deployment Profile"
	pac paportal upload --path "$portalExtractPath"
}

if ($LastExitCode -ne 0 ){
	# TODO dynamics get the path
	$pacLogAgent = "D:\Microsoft.PowerApps.CLI\Microsoft.PowerApps.CLI.1.20.3\tools\logs\pac-log.txt"
	if (Test-Path -Path $pacLogAgent){
		Get-Content $pacLogAgent
	}
	throw "Failed Uploading portals to path $targetEnvironment"
} 