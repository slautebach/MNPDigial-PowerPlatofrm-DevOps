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
$unManagedSolutionZipFile = "$($PackageData.SolutionsPath)\$($solutionName)_unmanaged.zip"
$managedSolutionZipFile = "$($PackageData.SolutionsPath)\$($solutionName)_managed.zip"

Write-Host "Packaging Solution: $solutionName"
Write-Host "Packaging Solution from: $solutionExtractPath"

Remove-Item $unManagedSolutionZipFile -ErrorAction SilentlyContinue
Remove-Item $managedSolutionZipFile -ErrorAction SilentlyContinue

##############
# UnManged
##############
$LastExitCode = 0
# Extract the solution
pac solution pack --zipfile $unManagedSolutionZipFile --folder $solutionExtractPath --packagetype Unmanaged --allowDelete --allowWrite --clobber --map $mapFile
if ($LastExitCode -ne 0 ){
	throw "Error packaging solution folder: $solutionExtractPath to solutionFile: $unManagedSolutionZipFile"
} 

Write-Host "Copying $unManagedSolutionZipFile to $buildPackagePath"
Copy-Item -Path $unManagedSolutionZipFile -Destination $buildPackagePath 


##############
# Manged
##############
$LastExitCode = 0
# Extract the solution
pac solution pack --zipfile $managedSolutionZipFile --folder $solutionExtractPath --packagetype Managed --allowDelete --allowWrite --clobber --map $mapFile
if ($LastExitCode -ne 0 ){
	throw "Error packaging solution folder: $solutionExtractPath to solutionFile: $managedSolutionZipFile"
} 

Write-Host "Copying $managedSolutionZipFile to $buildPackagePath"
Copy-Item -Path $managedSolutionZipFile -Destination $buildPackagePath 