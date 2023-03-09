param(
   [switch] $Force # force it to be built even if it is not enabled in the package.yml
) 


# Load the Package Data
Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

Load-PackageData

if (!$Force -and !$PackageData.BuildPackages.Portal){
	Write-Host "Portal Build is not enabled"
	exit
}

$portalSourceFolder = "$PSScriptRoot\..\Portals\$($PackageData.PortalName)"


$buildPackagePath = $PackageData.BuildPackagePath

Remove-Item "$buildPackagePath\$($PackageData.PortalName).zip" -Force -ErrorAction SilentlyContinue | Out-Null

Write-Host "******************************************************************************"
Write-Host "*    Building Portal Package"
Write-Host "******************************************************************************"

# We copied the files to a shorter path, so we can then successfully compress them into a zip file.
# once we can rename the records to reduce the max file length we can directly compress the archive.
Write-Host Compress-Archive -Path "$portalSourceFolder\*" -DestinationPath "$buildPackagePath\$($PackageData.PortalName).zip"
Compress-Archive -Path "$portalSourceFolder\*" -DestinationPath "$buildPackagePath\$($PackageData.PortalName).zip"

