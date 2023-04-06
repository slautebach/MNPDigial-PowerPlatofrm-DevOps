param(
	[Parameter(Mandatory=$true)]
	[string] $targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
	[string] $targetBranch = "main",
	[string] $appId = "", # optional app id to connect to dataverse
	[string] $clientSecret = "", #  client secret for the app id
	[String[]] $packages,
	[string] $SystemAccessToken = $ENV:SYSTEM_ACCESSTOKEN,             
	[string] $RequestedFor = $ENV:BUILD_REQUESTEDFOR,
	[string] $RequestedForEmail = $ENV:BUILD_REQUESTEDFOREMAIL,
	[string] $RepositoryId = $ENV:BUILD_REPOSITORY_ID,
	# Update this with your Azure DevOps Project
	[string] $devOpsProjectUrl = "",
	[string] $buildPackageFile = "Package", # The Build Package file to use
	[switch] $skipChecks
) 

Write-Host "Environment: $targetEnvironment"

# If triggered by DevOps, set the email to DevOps
if ($RequestedForEmail -eq $null -or $RequestedForEmail -eq ""){
	$RequestedForEmail = "devops@nserc-crsng.gc.ca"
}

if (!$skipChecks){
	# Check all the environment defaults are defined.
	if ($SystemAccessToken -eq ""){
		throw "SystemAccessToken for is not specified or not an environment variable."
	}
	if ($RequestedFor -eq ""){
		throw "Requested for is not specified or not an environment variable."
	}
	if ($RequestedForEmail -eq ""){
		throw "RequestedForEmail for is not specified or not an environment variable."
	}
	if ($RepositoryId -eq ""){
		throw "RequestedForEmail for is not specified or not an environment variable."
	}
}


# Load build package info
Import-Module "$PSScriptRoot\..\BuildScripts\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

Load-PackageData -targetEnvironment $targetEnvironment -logConfig:$logConfig

if (!$packages){
	$packages = @("solution", "portal", "data", "webfiles")
}

$PRBranchPath = $packages -join "-"
$PRBranchPath = "$PRBranchPath-prs"
$solutionName = $PackageData.SolutionName

$SolutionPRBranch = "$PRBranchPath/$solutionName"

$devOpsProjectUrl = "https://dev.azure.com/$($PackageData.DevOpsOrganization)/$($PackageData.DevOpProject)/"

#***************************************************************************
#*   Setup the Repository
#***************************************************************************

# move to the root directory of the project
cd "$PSScriptRoot\..\"

pwd

Write-Host ""
Write-Host "=============================================================="
Write-Host "Create Pull Request For Branch: $SolutionPRBranch"
Write-Host "=============================================================="

Write-Host "Git Config"
git config user.email $RequestedForEmail
git config user.name $RequestedFor
git config core.autocrlf false


Write-Host "git switch $targetBranch"
git switch $targetBranch

Write-Host "git checkout HEAD ."
git checkout HEAD .

Write-Host "git clean -fxd"
git clean -fxd

Write-Host "git fetch"
git -c http.extraheader="AUTHORIZATION: bearer $SystemAccessToken"  fetch

Write-Host "git pull origin $targetBranch"
git -c http.extraheader="AUTHORIZATION: bearer $SystemAccessToken" pull origin $targetBranch

# make sure it is reset to $targetBranch.
Write-Host "git reset --hard origin/$targetBranch"
git reset --hard origin/$targetBranch

$branchVerify =  git rev-parse --verify $SolutionPRBranch
if ($branchVerify){
	Write-Host "Deleting local branh $SolutionPRBranch"
	git branch -D $SolutionPRBranch
}

# branch origin/target to solution pr branch
Write-Host "git branch  $SolutionPRBranch"
git branch  $SolutionPRBranch

#check out the branch
Write-Host "git checkout $SolutionPRBranch"
git checkout $SolutionPRBranch


Write-Host "git checkout HEAD ."
git checkout HEAD .

# Set the environment task variable SolutionPRBranch
Write-Output "##vso[task.setvariable variable=SolutionPRBranch]$SolutionPRBranch"



Write-Host ""
Write-Host "=============================================================="
Write-Host "Install PAC CLI"
Write-Host "=============================================================="
# Install Power Apps CLI
InstallPAC

Write-Host ""
Write-Host "=============================================================="
Write-Host "Connect to Dataverse"
Write-Host "=============================================================="
SetPACConnections  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret -logConfig


Write-Host ""
Write-Host "=============================================================="
Write-Host "Prepare and extract packages"
Write-Host "=============================================================="

Write-Host "Target Environment: $targetEnvironment"

Write-Host "cd $PSScriptRoot\"
cd "$PSScriptRoot\"

Write-Host "Update Build Number"
"$PSScriptRoot\UpdateBuildNumber.ps1" 

# Get the list of packages enabled for build.
$buildPackages = $PackageData.BuildPackages

$BuildScriptsRoot = "$PSScriptRoot\..\BuildScripts\"

# If Solution Build is on, build the solution
if ($packages.Contains("solution")){
	Write-Host "******************************************************************************"
	Write-Host "*    Extracting Solution"
	Write-Host "******************************************************************************"
	. "$BuildScriptsRoot\Export-Solution.ps1" -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret
	Write-Host "******************************************************************************"
	Write-Host "******************************************************************************"
}


if ($packages.Contains("portal")){
	Write-Host "******************************************************************************"
	Write-Host "*    Extracting Portal"
	Write-Host "******************************************************************************"
	. "$BuildScriptsRoot\Export-Portal.ps1" -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret
	Write-Host "******************************************************************************"
	Write-Host "******************************************************************************"
}

if ($packages.Contains("portal-pdf-templates")){
	Write-Host "******************************************************************************"
	Write-Host "*    Extracting Portal"
	Write-Host "******************************************************************************"
	. "$BuildScriptsRoot\Export-Portal-PDF-Templates.ps1" -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret
	Write-Host "******************************************************************************"
	Write-Host "******************************************************************************"
}


if ($packages.Contains("data")){
	Write-Host "******************************************************************************"
	Write-Host "*    Extracting Data"
	Write-Host "******************************************************************************"
	. "$BuildScriptsRoot\Export-Data.ps1" -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret
	Write-Host "******************************************************************************"
	Write-Host "******************************************************************************"
}

if ($packages.Contains("webfiles")){
	if ($PSVersionTable.PSEdition -ne "Core"){
		Write-Host "******************************************************************************************"
		Write-Host "* Please run under Azure CLI PS Core to download portal webfiles and comment to source"
		Write-Host "******************************************************************************************"
	} else {
		Write-Host "******************************************************************************"
		Write-Host "*    Downloading On-Prem WebFiles to migrate to the Cloud Development Source."
		Write-Host "******************************************************************************"
		. "$BuildScriptsRoot\DeployScripts\Cloud-Migration\Download-DevConv-Webfiles.ps1" 
	}
	Write-Host "******************************************************************************"
	Write-Host "******************************************************************************"
}


Write-Host ""
Write-Host "=============================================================="
Write-Host "Adding Files to Git"
Write-Host "=============================================================="

# move to the root directory of the project
Write-Host "cd $PSScriptRoot\..\"
cd "$PSScriptRoot\..\"

$LastExitCode = 0
Write-Host ""
Write-Host "=============================================================="
Write-Host "Adding Files to Git"
Write-Host "=============================================================="
git add --all
if ($LastExitCode -ne 0 ){
	throw "Error Adding Files"
} 
Write-Host "=============================================================="
Write-Host "Adding Complete"
Write-Host "=============================================================="

$commitMessage="Committing Changes for: $PRBranchPath/$solutionName requested by $RequestedFor <$RequestedForEmail>"
$LastExitCode = 0
Write-Host ""
Write-Host "=============================================================="
Write-Host "Commit Message: $commitMessage"
Write-Host "=============================================================="
git commit -m $commitMessage
if ($LastExitCode -ne 0 ){
	throw "Error Committing Files"
} 
Write-Host "=============================================================="
Write-Host "Commit Complete"
Write-Host "=============================================================="

$LastExitCode = 0
Write-Host ""
Write-Host "=============================================================="
Write-Host "Git Push: --force origin $SolutionPRBranch"
Write-Host "=============================================================="
# Push changes 
git -c http.extraheader="AUTHORIZATION: bearer $SystemAccessToken" push --force origin $SolutionPRBranch
if ($LastExitCode -ne 0 ){
	throw "Error Pushing Branch"
} 

####################
# Create Pull Request - https://docs.microsoft.com/en-us/rest/api/azure/devops/git/pull%20requests/create?view=azure-devops-rest-5.0
####################
$headers = @{Authorization="Bearer $SystemAccessToken"} 
Write-Host "Token: $SystemAccessToken"

$PR=@{
  sourceRefName="refs/heads/$SolutionPRBranch"
  targetRefName="refs/heads/$targetBranch"
  title= "$commitMessage"
  description="$commitMessage"
  isDraft=$false
}

Write-Host ""
Write-Host "=============================================================="
Write-Host "Create/Update Pull Request"
Write-Host "=============================================================="
# Check if the PR already exists
$getUrl = "$devOpsProjectUrl/_apis/git/repositories/$RepositoryId/pullrequests?searchCriteria.status=active&searchCriteria.sourceRefName=$($PR.sourceRefName)&searchCriteria.targetRefName=$($PR.targetRefName)&api-version=5.0"
Write-Host "Get List of existing Pull Requests Url: $getUrl"
$result = Invoke-RestMethod -Headers $headers -Uri $getUrl -Method GET -ContentType "application/json"
Write-Host $result
Write-Host $result.Count

if ($result.Count -gt 0){
    Write-Host "Pull Request already exists, it has been updated"
    exit;
}

Write-Host "Creating Pull Request"

$prjson = $PR | ConvertTo-Json
Write-Host $prjson

$postURL = "$devOpsProjectUrl/_apis/git/repositories/$RepositoryId/pullrequests?api-version=5.0"
Write-Host "PostURL: $postURL"


# https://dev.azure.com/{organization}/{project}/_apis/git/repositories/{repositoryId}/pullrequests?api-version=5.0
$result = Invoke-RestMethod -Headers $headers -Uri $postURL  -Method POST -Body $prjson -ContentType "application/json" 

Write-Host $result