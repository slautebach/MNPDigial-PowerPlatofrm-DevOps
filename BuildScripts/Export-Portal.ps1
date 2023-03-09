param(
	[Parameter(Mandatory=$true)]
	[string]$targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
	[string]$appId, # optional app id to connect to dataverse
	[string]$clientSecret, #  client secret for the app id
	[switch] $Force 
) 


Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

SetPACConnections  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret



if (!$Force -and !$PackageData.BuildPackages.Portal){
	Write-Host "Portal Export is not enabled in package.yml"
	exit
}


#Root folder of the extracted portals path.
$PortalsPath = "$PSScriptRoot\..\Portals"

$LastExitCode = 0

# download the Portal
pac paportal download --path "$PortalsPath" --overwrite --webSiteId $PackageData.PortalId
if ($LastExitCode -ne 0 ){
	throw "downloading portals to path $PortalsPath"
} 


Write-Host "Loading Files"
$maxPath = 260
$files = Get-ChildItem -Path "$PortalsPath\$($PackageData.PortalName)" -Recurse

$portalsDir = Get-Item "$PortalsPath\$($PackageData.PortalName)"
$maxPathFiles = @();
$files | ForEach-Object {
	if ($_.FullName.Length -gt $maxPath){
		$fileName = $_.FullName.Replace($portalsDir.FullName, "")
		Write-Warning "Path to '$fileName', exceeds the maximum filename length of $maxPath, MAKE changes to the portals record name to reduce it, deleting it in the mean time."
		Remove-Item -Path  "\\?\$($_.FullName)" -Force
		$maxPathFiles += [PSCustomObject] @{"deleted file" = $fileName}
	}
}
