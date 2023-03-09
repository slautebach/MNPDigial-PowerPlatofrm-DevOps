param(
    [Parameter(Mandatory=$true)]
	[string] $targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
	[string] $appId = "", # optional app id to connect to dataverse
	[string] $clientSecret = "" #  client secret for the app id
) 

# Load the Build Package Details
Import-Module "$PSScriptRoot\..\..\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

SetPACConnections  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret -logConfig

# get the solution name
$solutionName = $PackageData.SolutionName


#Defin the path to the data zip file
$dataZipFile = "$($PackageData.BuildPackagePath)\$solutionName-Data.zip"


$LastExitCode = 0
Write-Host "Deploying Data Zip $dataZipFile to $targetEnvironment"
pac data import --data $dataZipFile --verbose
if ($LastExitCode -ne 0 ){
	throw "Error deploying Data Zip $dataZipFile to $targetEnvironment"
} 
