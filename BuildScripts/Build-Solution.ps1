param(
	[string]$solutionName, # solution name to extract
	[switch]$UpdateSolutionMasterOnly, # used to extract and update solution master, then delete the extracted solution.
    [switch] $Force # force it to be built even if it is not enabled in the package.yml
) 

# Load the Package Data
Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

Load-PackageData

$buildPackagePath = $PackageData.BuildPackagePath

if (!$Force -and !$PackageData.BuildPackages.Solution){
	Write-Host "Solution Build is not enabled"
	exit
}

# if solution is not specified, then get it from the version.json file.
if ($solutionName -eq ""){
	$solutionName = $PackageData.SolutionName
}

#Constants
$SolutionsPath = "$($PackageData.SolutionsPath)\..\Solutions"
$solutionExtractPath = "$($PackageData.SolutionsPath)\$solutionName\"
$mapFile  = "$($PackageData.SolutionsPath)\mapping.xml"
$solutionZipFile = "$($PackageData.SolutionsPath)\$solutionName.zip"

Write-Host "Packaging Solution: $solutionName"
Write-Host "Packaging Solution from: $solutionExtractPath"

Remove-Item $solutionZipFile -ErrorAction SilentlyContinue

$LastExitCode = 0
# Extract the solution
pac solution pack --zipfile $solutionZipFile --folder $solutionExtractPath --packagetype Unmanaged --allowDelete --allowWrite --clobber --map $mapFile
if ($LastExitCode -ne 0 ){
	throw "Error packaging solution folder: $solutionExtractPath to solutionFile: $solutionZipFile"
} 

Write-Host "Copying $PSScriptRoot\..\Solutions\$solutionName.zip to $buildPackagePath"
Copy-Item -Path "$PSScriptRoot\..\Solutions\$solutionName.zip" -Destination $buildPackagePath 