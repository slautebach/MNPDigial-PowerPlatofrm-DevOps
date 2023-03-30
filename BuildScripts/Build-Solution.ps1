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


Write-Host ""
Write-Host "***************************************************"
Write-Host "Checking Web Resource Files for file extensions"
Write-Host "***************************************************"
$WebResourcePath = "$PSScriptRoot\..\WebResources"
$files = Get-ChildItem -Path $WebResourcePath -Recurse -ErrorAction SilentlyContinue -Force

# file that lists webresource files to ignore.  These are files without an extension (or legacy)
$ignoreFiles = Get-Content -Path  "$PSScriptRoot\..\WebResources\.build-ignore-legacy"

# list of files that we need to list and error on.
$webResourceFileErrors = @()

# iterate through each web resource file to check
$files | ForEach-Object {
	$file = $_
	if ($file.Extension){
		# file has an extension continue
		return;
	}
	
	if ($file -is [System.IO.DirectoryInfo]){
		# file has an extension continue
		return;
	}

	$fileFullName = $file.FullName.ToLower().Replace("\", "/")

	$canIgnoreFile = $false
	$ignoreFiles | ForEach-Object {
		$ignoreLine = $_.Trim().ToLower().Replace("\", "/")		
		# if it is a comment or empty line skip
		if ($ignoreLine.StartsWith("#") -or $ignoreLine.Length -eq 0){
			return;
		}
		if ($fileFullName.Contains($ignoreLine)){
			$canIgnoreFile = $true
			return
		}
	}
	# we are to ignore the file skip
	if ($canIgnoreFile){
		Write-Host "Ignoring File $($file.FullName)  "
		return;
	}
	$webResourceFileErrors += $file.FullName
}

if ($webResourceFileErrors.Length -gt 0){
	Write-Host ""
	Write-Host  -ForegroundColor Red "********************************************************************"
	Write-Host  -ForegroundColor Red "Error with Web Resource File Extensions"
	Write-Host  -ForegroundColor Red "********************************************************************"
	Write-Host  -ForegroundColor Red "You have web resource files that are missing file extensions."
	Write-Host  -ForegroundColor Red "Please update the webresource name (or re-create it) with a proper"
	Write-Host  -ForegroundColor Red "name and file extension.  Otherwise it breaks the DevOps/Code review"
	Write-Host  -ForegroundColor Red "capabilities."
	Write-Host  -ForegroundColor Red "The following files are missing file extensions that need to be corrected:"
	$webResourceFileErrors | ForEach-Object {
		Write-Host  -ForegroundColor Red "    $_"
	}
	throw "Error validating web resource file extensions"
}






#Constants
$SolutionsPath = "$($PackageData.SolutionsPath)\..\Solutions"
$solutionExtractPath = "$($PackageData.SolutionsPath)\$solutionName\"
$managedSolutionExtractPath = "$($PackageData.SolutionsPath)\$($solutionName)_managed\"
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
pac solution pack --zipfile $managedSolutionZipFile --folder $managedSolutionExtractPath --packagetype Managed --allowDelete --allowWrite --clobber --map $mapFile
if ($LastExitCode -ne 0 ){
	throw "Error packaging solution folder: $managedSolutionExtractPath to solutionFile: $managedSolutionZipFile"
} 

Write-Host "Copying $managedSolutionZipFile to $buildPackagePath"
Copy-Item -Path $managedSolutionZipFile -Destination $buildPackagePath 