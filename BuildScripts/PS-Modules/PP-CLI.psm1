Import-Module "$PSScriptRoot\Functions.psm1"  -DisableNameChecking
Load-Module Microsoft.PowerApps.Administration.PowerShell

function InstallPAC(){
    $pacInstallPath = Build-NuGet Microsoft.PowerApps.CLI

    Write-Host $pacInstallPath


    # find the executable and add it to the environment path
    $pacNugetFolder = Get-ChildItem $pacInstallPath | Where-Object {$_.Name -match "Microsoft.PowerApps.CLI."}
    $pacPath = $pacNugetFolder.FullName + "\tools"

    # if the path does not contain the pacPath, then add it.
    if (!($env:PATH.Contains($pacPath))){
	    $env:PATH = "${env:PATH};$pacPath"
	    #Add pac to the path into DevOps pipeline
	    Write-Host "##vso[task.setvariable variable=PATH;]${env:PATH};$pacPath";
    }
}

function InitializePACConnection(){
	param(
		[string]$targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
		[string]$appId, # optional app id to connect to dataverse
		[string]$clientSecret, #  client secret for the app id
		[string]$tenant
	)
    if ($targetEnvironment -eq ""){
        Write-Warning "No Target Environment Specified"
    }
	# Check to make sure the power platform cli is installed and available.
	if ((Get-Command "pac" -ErrorAction SilentlyContinue) -eq $null) 
	{ 
		InstallPAC
	}

	# Check to make sure the power platform cli is installed and available.
	if ((Get-Command "pac" -ErrorAction SilentlyContinue) -eq $null) 
	{ 
		Write-Host "Unable to find Power Platform CLI"
		Write-Host "Please install it from: https://docs.microsoft.com/en-us/power-platform/developer/cli/introduction"
	}

	$url = "https://$targetEnvironment.crm3.dynamics.com/"

	# Check if the connection can be selected.
	# if we get back an error on selecting the connection, then it doesn't exist and we must create it. 
	if (pac auth select --name "$targetEnvironment" | Select-String -Pattern "^Error:"){
		Write-Host "Creating authentication profile for $targetEnvironment Url: $url"
		# if not, create it.
		if ($appId){
			Write-Host "Connecting with App Id"
			pac auth create --name $targetEnvironment --url $url --environment $url --applicationId $appId  --clientSecret $clientSecret  --tenant $tenant
		} else {
			Write-Host "Connecting Interactive"
			pac auth create --name $targetEnvironment --url $url  --environment $url
		}
	} else {
		Write-Host "$targetEnvironment Found"
	}
	Write-Host "pac switching auth to $targetEnvironment"
	if (pac auth select --name "$targetEnvironment" | Select-String -Pattern "^Error:"){
		throw "Unable to switch to '$targetEnvironment'"
	}
}



function InitializePACConnectionAdmin(){
	param(
		[string]$targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
		[string]$appId , # optional app id to connect to dataverse
		[string]$clientSecret, #  client secret for the app id
		[string]$tenant 
	)
    if ($targetEnvironment -eq ""){
        Write-Warning "No Target Environment Specified"
    }

	# Check to make sure the power platform cli is installed and available.
	if ((Get-Command "pac" -ErrorAction SilentlyContinue) -eq $null) 
	{ 
		InstallPAC
	}

	# Check to make sure the power platform cli is installed and available.
	if ((Get-Command "pac" -ErrorAction SilentlyContinue) -eq $null) 
	{ 
		Write-Host "Unable to find Power Platform CLI"
		Write-Host "Please install it from: https://docs.microsoft.com/en-us/power-platform/developer/cli/introduction"
	}

	 

	$url = "https://$targetEnvironment.crm3.dynamics.com/"

	$adminEnvName = "$targetEnvironment-admin"
	# Check if the connection can be selected.
	# if we get back an error on selecting the connection, then it doesn't exist and we must create it. 
	if (pac auth select --name "$adminEnvName" | Select-String -Pattern "^Error:"){
		Write-Host "Creating Admin authentication profile for $adminEnvName Url: $url"
		# if not, create it.
		if ($appId){
			Write-Host "Connecting with App Id"
			pac auth create --name $adminEnvName --url $url --environment $url --applicationId $appId  --clientSecret $clientSecret  --tenant $tenant --kind admin
			Write-Host "Connecting with Microsoft.PowerApps.Administration.PowerShell"
			Add-PowerAppsAccount -ApplicationId $appId -ClientSecret $clientSecret -TenantID $tenant
		} else {
			Write-Host "Connecting Interactive"
			pac auth create --name $adminEnvName --url $url  --environment $url  --kind admin
			Write-Host "Connecting with Microsoft.PowerApps.Administration.PowerShell"
			Add-PowerAppsAccount 
		}
	} else {
		Write-Host "$targetEnvironment-admin Found"
	}
	Write-Host "pac switching auth to $adminEnvName"
	if (pac auth select --name "$adminEnvName"  | Select-String -Pattern "^Error:"){
		throw "Unable to switch to '$adminEnvName'"
	}
}

function Get-AdminStatus(){
	$statusOutput = pac admin status | Out-String
	$statusOutput = $statusOutput.Trim()
	if ($statusOutput.StartsWith("No async operation")){
		return $null
	}
	$statusOutput = $statusOutput.Replace("   ", ",")

	while ($statusOutput.Contains(",,")){
		$statusOutput = $statusOutput.Replace(", ", ",")
		$statusOutput = $statusOutput.Replace(",,", ",")
	}
	
	$status = $statusOutput | ConvertFrom-Csv
	return $status
}

# Uses the Powershell Power Apps Admin Module
#https://learn.microsoft.com/en-us/powershell/module/microsoft.powerapps.administration.powershell/copy-powerappenvironment?view=pa-ps-latest
function Copy-PAppEnvironment(){
	param(
		[string]$sourceEnvironment , # source environment
		[string]$targetEnvironment  # target environment
	)
	Write-Host ""
	Write-Host "=================================================================="
	Write-Host "Copying $sourceEnvironment to $targetEnvironment"
	Write-Host "=================================================================="
	
	$sourceEnvironmentData = Get-AdminPowerAppEnvironment $sourceEnvironment
	$targetEnvironmentData = Get-AdminPowerAppEnvironment $targetEnvironment

	if (!$targetEnvironmentData){
		throw "target $targetEnvironment environment does not exist, please create it."
	}

	$copyToRequest = [pscustomobject]@{
		"SourceEnvironmentId" = $sourceEnvironmentData.EnvironmentName
		"TargetEnvironmentName"= $targetEnvironment
		#"TargetSecurityGroupId" = "204162d5-59db-40c2-9788-2cda6b063f2b"
		"CopyType" = "FullCopy" #"MinimalCopy"
		"SkipAuditData" = $true
	}
	Write-Host "Using Copy-PowerAppEnvironment to copy $sourceEnvironment to $targetEnvironment"
	$copyToRequest | Format-List
	$response = Copy-PowerAppEnvironment -EnvironmentName $targetEnvironmentData.EnvironmentName -CopyToRequestDefinition $copyToRequest 

	# conver the headers dictionary to a hashtable
	$headers = [hashtable]$response.Headers
	#$headers | Format-List
	$operationUrl = $headers."operation-location"

	if (!$operationUrl -or $operationUrl -eq ""){
		throw "Unable to get a status operational url to query."
	}
	Write-Host "Operation Status URL: $operationUrl"

	Start-Sleep 5

	$operationResponse = Get-AdminPowerAppOperationStatus -OperationStatusUrl $operationUrl
	$response = $operationResponse.Internal.Content | ConvertFrom-Json
	$copyStart = (Get-Date)
	$timePassed = (Get-Date).Subtract($copyStart)


	while ($response -and $response.state.id -eq "Running"){
		Start-Sleep 20
		$operationResponse = Get-AdminPowerAppOperationStatus -OperationStatusUrl $operationUrl
		$response = $operationResponse.Internal | ConvertFrom-Json
		$timePassed = (Get-Date).Subtract($copyStart)

		Write-Host "************ Status ************"
		$validateStage = $response.stages | Where {$_.id -eq "Validate"}
		$prepare = $response.stages | Where {$_.id -eq "Prepare"}
		$run = $response.stages | Where {$_.id -eq "Run"}
		$finalize = $response.stages | Where {$_.id -eq "Finalize"}

		$dateStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		Write-Host "DateStamp  $dateStamp"
		Write-Host "Run Time   $($timePassed.Minutes) minutes, $($timePassed.Seconds) seconds"
		Write-Host "Validate:  $($validateStage.state.id)"
		Write-Host "Prepare:   $($prepare.state.id)"
		Write-Host "Copy Run:  $($run.state.id)"
		Write-Host "Finalize:  $($finalize.state.id)"
		Write-Host "********************************"		
	}

	Write-Host "Enabling the environment (aka disabling admin mode)"
	$response = Set-AdminPowerAppEnvironmentRuntimeState -EnvironmentName $targetEnvironmentData.EnvironmentName -RuntimeState Enabled

	#$jsonResponse = $response.Internal | ConvertFrom-Json 
	#$jsonResponse | Format-List
}
function Copy-PACEnvironment(){
	param(
		[string]$sourceEnvironment , # source environment
		[string]$targetEnvironment,  # target environment
		[switch]$async 
	)
	Write-Host ""
	Write-Host "=================================================================="
	Write-Host "Copying $sourceEnvironment to $targetEnvironment"
	Write-Host "=================================================================="
	$LastExitCode = 0
	if (!$async){
		pac admin copy --source-env https://$sourceEnvironment.crm3.dynamics.com/ --target-env https://$targetEnvironment.crm3.dynamics.com/ --type FullCopy 
		if ($LastExitCode -ne 0 ){
			throw "Error copying $sourceEnvironment to $targetEnvironment"
		} 
		return
	}
	pac admin copy --source-env https://$sourceEnvironment.crm3.dynamics.com/ --target-env https://$targetEnvironment.crm3.dynamics.com/ --type FullCopy --async
	if ($LastExitCode -ne 0 ){
		throw "Error copying $sourceEnvironment to $targetEnvironment"
	} 
	
	$adminStatus = Get-AdminStatus
	$theStatus = @{}
	$lTimeStamp = ""
	$adminStatus | ForEach-Object {
		# get the current time
		$cStamp = [DateTime]$_."Start Time"
		if ($lTimeStamp -eq "" -or $lStamp.Subtract($cStamp).Ticks -ge 0){
			$lTimeStamp = $cStamp
			$theStatus = $_
		}
	}

	# loop while admin status is not null or the status is not null
	while ($adminStatus -ne $null -or $theStatus -ne $null){
		# set the status to null
		$theStatus = $null
		$adminStatus | ForEach-Object {
			Write-Host "Current Status: $($_.Status), Operation $($_.Operation), Start Time: $($_."Start Time")"
			$cStamp = [DateTime]$_."Start Time"
			if ($cStamp -eq $lTimeStamp){
				# if found set the status
				$theStatus = $_
			}
		}
		# wait for 30 seconds
		Start-Sleep -Seconds 30

		# re-retrieve the statuses
		$adminStatus = Get-AdminStatus
	}
}

<#
Initialzies the pac cli connection details
#>
function ReInitializePACConnection(){

    Write-Host ""
    Write-Host ""
    Write-Host "************************************************"
    Write-Host "Initializing PAC Connections"
    Write-Host "************************************************"
    # Check to make sure the power platform cli is installed and available.
	if ((Get-Command "pac" -ErrorAction SilentlyContinue) -eq $null) 
	{ 
		InstallPAC
	}
    if ($global:PACConnectionDetails.resetAuth){
		# disabled delete and going back to clear until time permits to test and debug
        #Write-Host "Deleting PAC Connections: $targetEnvironment and $targetEnvironment-admin"
        #pac auth delete --name "$targetEnvironment-admin" | Out-Null
		#pac auth delete --name $targetEnvironment | Out-Null
		Write-Host "Clearing PAC Connections"
		pac auth clear
    }
  
    if ($global:PACConnectionDetails.requireAdmin){
        # Set the Admin Connection First
        InitializePACConnectionAdmin  -targetEnvironment $global:PACConnectionDetails.targetEnvironment -appId $global:PACConnectionDetails.appId -clientSecret $global:PACConnectionDetails.clientSecret -tenant $global:PACConnectionDetails.tenant
    }

    # Set the Pac default Connection
    InitializePACConnection  -targetEnvironment $global:PACConnectionDetails.targetEnvironment -appId $global:PACConnectionDetails.appId -clientSecret $global:PACConnectionDetails.clientSecret -tenant $global:PACConnectionDetails.tenant

    Write-Host ""
    Write-Host ""
    pac auth list
    Write-Host ""
    Write-Host ""
}

$global:PACConnectionDetails = @{}
function SetPACConnections(){
    param(
        [string] $targetEnvironment,
        [string] $appId, # optional app id to connect to dataverse
	    [string] $clientSecret, #  client secret for the app id
	    [string] $tenant,
        [switch] $logConfig,
        [switch] $requireAdmin,
        [switch] $resetAuth
    )
    
    Load-PackageData -targetEnvironment $targetEnvironment -logConfig:$logConfig

    # Set Connection Details
    $global:PACConnectionDetails.targetEnvironment = $targetEnvironment
    $global:PACConnectionDetails.appId = $appId
    $global:PACConnectionDetails.clientSecret = $clientSecret
    $global:PACConnectionDetails.tenant = $tenant
    $global:PACConnectionDetails.logConfig = $logConfig
    $global:PACConnectionDetails.tenant = $tenant
    $global:PACConnectionDetails.resetAuth = $resetAuth
    $global:PACConnectionDetails.requireAdmin = $requireAdmin
    ReInitializePACConnection 
    
}


function ImportSolution(){
	param(
		[string]$solutionZipFile,
		[switch] $unmanaged
	)

	$stopwatch =  [system.diagnostics.stopwatch]::StartNew()
	$LastExitCode = 0

	# TODO - for managed solutions deploy the solution as holding first then apply the upgrade
	Write-Host pac solution import --path $solutionZipFile --activate-plugins --force-overwrite --async 
	pac solution import --path $solutionZipFile --activate-plugins --force-overwrite --async > output.log
	$stopwatch.Stop()
	if (($LastExitCode -ne 0 ) -or (Get-Content .\output.log | Select-String -Pattern "^Error:")){
		Write-Host "Last Error Code: $LastExitCode"
		Write-Host "***********************************************"
		Write-Host " Error importing, Log output: "
		Write-Host "***********************************************"
		cat output.log
		throw "Failed to import solution $solutionZipFile"
	} 
	Write-Host "Took $($stopwatch.Elapsed.Minutes) minutes,  $($stopwatch.Elapsed.Seconds) seconds to import $filePath"
	PublishSolutions

	WaitForNorth52 -timeout 60 -queryWait 30000
}

<#
Runs a Publish All
#>
function PublishSolutions(){
    ReInitializePACConnection
    Write-Host ""
    Write-Host "***********************************************"
    Write-Host "Publishing Changes"
    Write-Host "***********************************************"
    pac solution publish
    # if published failed
    if ($LastExitCode -ne 0 ){
        Write-Host "Publish FAILED: "
        Write-Host "   failed to publish all, after importing solutions.  Ignroing failure"
           
        $LastExitCode = 0
        $Error.Clear() 
    }else{
        Write-Host "Publish successful"
    }
    Write-Host "-----------------------------------------------------------------"

}



Export-ModuleMember -Function * -Alias *
