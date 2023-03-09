
if ($PSVersionTable.PSEdition -ne "Desktop"){
    throw "This module needs PS Desktop edition, please run your script from a version of PowerShell (ie PS 5.x)"
}

Import-Module "$PSScriptRoot\Functions.psm1" -Force  -DisableNameChecking
Import-Module "$PSScriptRoot\Build-Package.psm1" -Force  -DisableNameChecking

#Note this Powershell Module 5.x
Load-Module Microsoft.Xrm.Data.Powershell 

<#
Set-Entity-State Setst the state of an entity
#>
function Set-Entity-State{
    param(
        $Conn,
        [string] $LogicalName,
        [string] $Id,
        [int] $State,
        [int] $Status        
    ) 
    $setStateReq = new-object Microsoft.Crm.Sdk.Messages.SetStateRequest 
    $setStateReq.EntityMoniker = New-Object Microsoft.Xrm.Sdk.EntityReference  
    $setStateReq.EntityMoniker.LogicalName = $LogicalName
    $setStateReq.EntityMoniker.Id = [Guid]::Parse($Id)
    $setStateReq.State = New-CrmOptionSetValue -Value $State
    $setStateReq.Status = New-CrmOptionSetValue -Value $Status   
    $Conn.ExecuteCrmOrganizationRequest($setStateReq)
}


<#
Set-Entity-State Setst the state of an entity
NOTE: Only works with CRM v9.0 or greater
We must wait to upgrade before we can use this.
#>
function Set-EncryptionKey{
    param(
        [string] $EncryptionKey
    ) 
    $dataEncryptionReq = new-object Microsoft.Crm.Sdk.Messages.SetDataEncryptionKeyRequest  
    $dataEncryptionReq.ChangeEncryptionKey  = $true
    $dataEncryptionReq.EncryptionKey = $EncryptionKey
    $Conn.ExecuteCrmOrganizationRequest($dataEncryptionReq)
}


function Set-Theme{
    param(
        # Setting Parameters
        [string] $OrgName = "Dynamics 365",
        [string] $navBackgroundColor = "",
        [string] $navForegroundColor = "#ffffff"
    )

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "   Configuring Default Theme"
    Write-Host "------------------------------------------------------------"

    # Create Image to upload
    Add-Type -AssemblyName System.Drawing
    Write-Host "Creating Theme Logo"
    $filename = "$PSScriptRoot\$OrgName.png" 
    $bmp = new-object System.Drawing.Bitmap 250,61 
    $font = new-object System.Drawing.Font Consolas,24 
    $brushBg = new-object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($navBackgroundColor))
    $brushFg = new-object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($navForegroundColor))
    $graphics = [System.Drawing.Graphics]::FromImage($bmp) 
    $graphics.FillRectangle($brushBg,0,0,$bmp.Width,$bmp.Height) 
    $graphics.DrawString($OrgName,$font,$brushFg,10,10) 
    $graphics.Dispose() 
    $bmp.Save($filename) 


    $logoId = "{5E77D2DF-F427-406B-A699-3E714BAC7C3E}"
    $EncodedImage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filename))

    Set-CrmRecord -conn $Conn -Upsert -EntityLogicalName "webresource" -Id $logoId -Fields @{ 
        "name" = "new_customtheme.png";
        "webresourcetype" = New-CrmOptionSetValue -Value 5;
        "content" = $EncodedImage
    }

    Publish-CrmCustomization -conn $Conn -WebResource -WebResourceIds @($logoId)

    $defaultThemeId = "{F499443D-2082-4938-8842-E7EE62DE9A23}"

    Write-Host "Retreiving Default theme."
    # get the default theme and its settings
    $defaultTheme = Get-CrmRecord -conn $Conn -EntityLogicalName "theme" -Id $defaultThemeId -Fields *
    if (!$navBackgroundColor){
        $navBackgroundColor = $defaultTheme.navbarbackgroundcolor
    }
    
    $customThemeId = "{758F0B6F-F119-4DCE-B909-B714F2E3C429}"
    # Create/UpSert Custom theme
    Write-Host "Creating new theme $OrgName."
    Set-CrmRecord -conn $Conn -Upsert -EntityLogicalName "theme" -Id $customThemeId -Fields @{ 
        "name" = $OrgName;
        "logotooltip" = $OrgName;
        "logoid" = New-CrmEntityReference -EntityLogicalName "webresource" -Id $logoId
        "navbarbackgroundcolor" = $navBackgroundColor;
        "headercolor" = $defaultTheme.headercolor;
        "defaultentitycolor" = $defaultTheme.defaultentitycolor;
        "controlborder" = $defaultTheme.controlborder;
        "controlshade" = $defaultTheme.controlshade;
        "selectedlinkeffect" = $defaultTheme.selectedlinkeffect;
        "backgroundcolor" = $defaultTheme.backgroundcolor;
        "globallinkcolor" = $defaultTheme.globallinkcolor;
        "processcontrolcolor" = $defaultTheme.processcontrolcolor;
        "hoverlinkeffect" = $defaultTheme.hoverlinkeffect;
        "navbarshelfcolor" = $defaultTheme.navbarshelfcolor;
    }

    #publish custom theme
    Write-Host "Publishing new theme $OrgName."
    Publish-CrmTheme -conn $Conn -ThemeId $customThemeId
}

function ConnectDataverseApi(){
    param(
        [string] $targetEnvironment,
        [string] $appId, # optional app id to connect to dataverse
	    [string] $clientSecret , #  client secret for the app id
	    [string] $connectionString,
        [string] $tenant        
    ) 
    $startOfUrl = "https://$targetEnvironment."
    $url = "https://$targetEnvironment.crm3.dynamics.com/"
    $CRMUrl = $url
  
    if ($connectionString){
        $CRMConnectionString=$connectionString
        $LogCRMConnectionString = "**********"
    } else {
        if ($Conn -ne $null -and $Conn.CrmConnectOrgUriActual.ToString().StartsWith($startOfUrl)) {
            Write-Host "Already Connected to $url"
            return
        }
        $CRMConnectionString="AuthType='ClientSecret'; ServiceUri='$url';ClientId='$appId'; ClientSecret='$clientSecret';Timeout=02:00:00"
        $LogCRMConnectionString="AuthType='ClientSecret'; ServiceUri='$url';ClientId='$appId'; ClientSecret='******************';Timeout=02:00:00"
    }

    if ($appId -eq "" -and $connectionString -eq ""){
        $CRMConnectionString="ServiceUri='$url';Timeout=02:00:00"
        $Conn = Get-CrmConnection -InteractiveMode
    } else {
        Write-Host "Connecting with Connection String: $LogCRMConnectionString"
        # Open a connection to CRM
        $Conn = Get-CrmConnection -ConnectionString "$CRMConnectionString"
    }
    # Set the connection as an global variable in the global scope
    Set-Variable -Name "Conn" -Visibility Public -Value $Conn -Scope global 

    if ($connectionString -eq "" -and !$Conn.CrmConnectOrgUriActual.ToString().StartsWith($startOfUrl)) {
        Write-Error "You are connected to '$($Conn.CrmConnectOrgUriActual.ToString())', but are expected to be connected to: $startOfUrl"
        Set-Variable -Name "Conn" -Visibility Public -Value $null -Scope global 
        exit
    }

    $whoAmI = Invoke-CrmWhoAmI -conn $Conn
    Write-Host "Connected to Organization '$($whoAmI.OrganizationId)'"
}


function ConfigureNorth52(){
    $Conn = $global:Conn
    ###############################
    # Configure N52
    ###############################

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "   Updating North52 Org Configuration"
    Write-Host "------------------------------------------------------------"

    #Reset - North52 Configuration Record - To the Organziation Id
    # Make an Who Am I request to get the organization id
    Write-Host "Retrieving Organization Id"
    $whoAmI = Invoke-CrmWhoAmI -conn $Conn
    
    Write-Host "Who Am I Details"
    Write-Object $whoAmI
    # update the n52 configuration with the organization id.

    $fetch = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='true' >
        <entity name='north52_configuration' >
            <attribute name='north52_configurationid' />
        </entity>
    </fetch>"
    
    Write-Host "Fetch North 52 Config"
    Write-Host $fetch

    # get the results, and if non are found return null
    $n52Configs = get-crmrecordsbyfetch  -conn $Conn -Fetch $fetch

    foreach ($record in $n52Configs.CrmRecords)
    {
        $fields =  @{
            "north52_organizationid"="$($whoAmI.OrganizationId)";
            "north52_fm_licenseaccepted"=$true
        } 
        Write-Host "Updating N52 Configuration; Setting N52 Config id: $($record.ReturnProperty_Id) setting fields: "
        Write-Object $fields
        Set-CrmRecord -conn $Conn -EntityLogicalName "north52_configuration" -Id  $record.ReturnProperty_Id -Fields $fields
    }
    Write-Host "Done updating N52 Configuration"
  
}

function Set-ConvRecords(){
    param(
        [string] $parametersFile,
        [string] $targetEnvironment
    )
    $targetRecords = Get-Parameters -environment $targetEnvironment -parametersFile $parametersFile

    foreach ($h in $targetRecords.GetEnumerator() ){

        $entityLogicalName = $h.Name
        $entityData = $h.Value

        $lookupAttributeName = $entityData.lookup_attribute
        $entities = $entityData.entities

        $values = ""
        $entities | ForEach {
            $values += "<value>$($_.$lookupAttributeName)</value>"
        }

        $fetch = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='true' >
          <entity name='$entityLogicalName' >
            <attribute name='$lookupAttributeName' />
            <attribute name='$($entityLogicalName)id' />
            <filter type='and' >
              <condition attribute='$lookupAttributeName' operator='in' >
                    $values
              </condition>
            </filter>
          </entity>
        </fetch>"

        #validate and format the fetchxml
        $fetchXml = [xml]$fetch
        $fetch = $fetchXml.OuterXml
        Write-Host "Fetch:"
        Write-Host "$fetch"
        try {
            # get the results, and if non are found return null
            $dataFilterFetchResults = get-crmrecordsbyfetch  -conn $Conn -Fetch $fetch
        }
        catch 
        {
            Write-Warning "Unable to retrieve records, for entity: $entityLogicalName skipping"
            $_ | Format-List
            return;
        }
        
        # Process the resutls and update setting the new specified values.
        Write-Host "======================================================================"
        Write-Host "=  Setting Convergnece Con:  $entityLogicalName "
        Write-Host "======================================================================"
        foreach ($record in $dataFilterFetchResults.CrmRecords)
        {
            $recordId = $record.ReturnProperty_Id
            # get the corresponding entity
            $entity = $entities | Where-Object {$_.$lookupAttributeName -eq $record.$lookupAttributeName}
            if ($entity.Length -eq 0){
                Write-Host "Record with name: $($record.lookupAttributeName) not found in source "
                continue
            }
            Write-Host "Updating EntityLogicalName $($record.logicalname), For record identified as: '$($record.$lookupAttributeName)' ($recordId) with Values: "
            if ($entity.GetType().Name -eq "PSCustomObject" ){
              $entity = ConvertTo-HashtableFromPsCustomObject $entity
            }
            $entity.Remove($lookupAttributeName)
            Write-Host "From System"
            Write-Object $record
            Write-Host "To Update $recordId"
            Write-Object $entity
            foreach ($key in  $entity.Keys){
                Write-Host "       $key = $($entity[$key])"
            }
            try{
                Set-CrmRecord -conn $Conn -EntityLogicalName $record.logicalname -Id  $recordId -Fields $entity
            } catch {
                Write-Warning "   Failed to update record"
                throw $_
            }
        }

    }
}


# Function to retrieve the latest N52 Publish All Job.  If it is more than $timeout minutes old, then return null, so we can wait for the new one to start.
function GetNorth52PostDeploymentAsyncJob(){
  # Defin the fetch used to query North 52 Publish Job.
    $fetch=@"
<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>
	<entity name='asyncoperation'>
		<attribute name='asyncoperationid' />
		<attribute name='name' />
		<attribute name='regardingobjectid' />
		<attribute name='operationtype' />
		<attribute name='statuscode' />
		<attribute name='startedon' />
		<attribute name='statecode' />
		<order attribute='startedon' descending='true' />
		<filter type='and'>
			<condition attribute='name' operator='like' value='%N52 Publish All%' />
            <condition attribute='startedon' operator='last-x-hours' value='2' />
		</filter>
	</entity>
</fetch>
"@
    $Conn = $global:Conn
    # get the results, and if non are found return null
    $results = get-crmrecordsbyfetch  -conn $Conn -Fetch $fetch -TopCount 1
    if ($results.Count -eq 0){
        Write-Debug "No N52 Publish Jobs Found"
        return $null
    }
    $N52Job = $results.CrmRecords[0]
    
   
    return $N52Job

}

function WaitForNorth52(){
     param(
         [int]$timeout = 30,
         [int]$queryWait = 10000
    ) 
    # Get the results of the N52 Publish Jobs
    $N52Job = GetNorth52PostDeploymentAsyncJob
    Write-Host "Looking for 'N52 Publish All' System Job, that started in the past hour ..."
    $queryCount = 0;
    
    # while no n52 publish job is not  found, retry for about 5 seconds.
    while ($N52Job -eq $null -and $queryCount -lt 5){
        # wiat .5 seconds  before next query loop
        Start-Sleep -Milliseconds $queryWait

        # output a "." to show wiat progress
        Write-Host "Looking for N52 Publish All ..."

        # retrieve the job
        $N52Job = GetNorth52PostDeploymentAsyncJob

        # increment query count
        $queryCount++;
    }

    # if no n52 publish job is found, throw an error.
    if ($N52Job -eq $null){
        # 5 or more seconds passed, and the N52 Publish Job was not found
        throw "N52 Publish Job was not found.  Please Investigate if the job did kick off.";
    }

    # Log the found job.
    Write-Host "Waiting on Job: '$($N52Job.name)' to complete, it started on: '$($N52Job.startedon)', Current State: '$($N52Job.statecode)', Status Reason: '$($N52Job.statuscode)"
 

    $startDate = [Datetime]$N52Job.startedon
    # calculate the current time passed
    $timePassed = $(Get-Date).ToUniversalTime().Subtract($N52Job.startedon_Property.Value.ToUniversalTime())
    Write-Host "Querying for N52 Job publish to complete. "
    Write-Host "Waiting $($timePassed.Minutes) minutes, $($timePassed.Seconds) seconds ..."
    $previousN52Job = $N52Job
    $continueLoop = $true
    $jobStartTime = $(Get-Date)
    $reason = ""
    # Loop while the job is in progress (not completed) time out after $timeout minutes
    While ($continueLoop){
        $previousN52Job = $N52Job
        Start-Sleep -Milliseconds $queryWait
        $timePassed = $(Get-Date).ToUniversalTime().Subtract($jobStartTime)
        Write-Host "Waiting $($timePassed.Minutes) minutes, $($timePassed.Seconds) seconds ..."
        $N52Job = GetNorth52PostDeploymentAsyncJob;
        $timePassed = (Get-Date).Subtract($startDate)

        
        if ($N52Job -eq $null){
            $reason = "North 52 Job not found"
            # if no job is found, stop looping
            $continueLoop = $false
        } elseif ($N52Job.Id -ne $previousN52Job.Id){
            # if the job id has changed, reset the start time.
            $jobStartTime = $(Get-Date)
            $continueLoop = $true
        }elseif ($N52Job.statecode -eq "Failed"){
            $reason = "North 52 Job Failed"
            # if the job failed 
              $continueLoop = $false
        } elseif ($N52Job.statecode -ne "Completed" -and $timePassed.Minutes -lt $timeout){
            # if the job is not completed and hasn't timed out
              $continueLoop = $true
        } else {
            $reason = "North 52 condition check failure"
            # if no job is found, stop looping
            $continueLoop = $false        
        }
    }


    # if the timeout has reached, log it.
    if ($timePassed.Minutes -ge $timeout){
        Write-Host "Timeout of $timeout minutes reached."
    }

    # if the job did not succeed, throw an error.
    if ($N52Job.statuscode -ne "Succeeded"){
        throw "North 52 Publish Job did not complete successfully, finshed with status '$($N52Job.statuscode)', Please Investigate.  Reason: $reason"
    }
    Write-Host "N52 Publish Completed successfully."

}



<#
Script Wrapper to run a CRM Powershell command remotely on $DeploymentServer
#>
function Run-Crm-Powershell {
    param(
        $crmUsername,
        $crmPassword,
        $remoteserver,
        $ScriptBlock
    )
    # Convert to SecureString
    [securestring]$secStringPassword = ConvertTo-SecureString $crmPassword -AsPlainText -Force
    # Create Credential object
    [pscredential]$Cred = New-Object System.Management.Automation.PSCredential ($crmUsername, $secStringPassword)
    # Setup the Session and Run The Script Block
    try {
        $session = New-PSSession -ComputerName $remoteserver -Credential $Cred -EnableNetworkAccess
        # Load the crm powershell module
        Invoke-Command -Session $session -ScriptBlock {
            Add-PSSnapin Microsoft.Crm.Powershell
        }
        # Run and return the results from the script block
        return Invoke-Command -Session $session -ScriptBlock $ScriptBlock
    }
    # Clean up the session.
    finally {
        if ($session -eq $null){
            Write-Host "Unable to establish PowerShell Session to $remoteserver"
        } else {
            Remove-PSSession -Session $session
        }
    }
}


function RestoreDatabase(){
     param(
         $username,
         $password,
         $BackupFile,
         $DBServerInstance,
         $database,
         $DataPath
    )

    [securestring]$secStringPassword = ConvertTo-SecureString $password -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential ($username, $secStringPassword)
    #Clear all DB Connections
    [System.Data.SqlClient.SqlConnection]::ClearAllPools()
    
    # Define Relocate Files
    $relocate = @()
    # extract the list of files to relocate

    $sqlCmd = "RESTORE FILELISTONLY FROM DISK='$BackupFile';"
    Write-Host "Running the following query on: $DBServerInstance"
    Write-Host $sqlCmd
    # using sql authentication
    $dbfiles = Invoke-Sqlcmd -ServerInstance $DBServerInstance -Credential $Cred  -Query $sqlCmd -OutputSqlErrors $true -verbose

    Write-Host "--------------------------"
    Write-Host "Determining relocate files"
    Write-Host "--------------------------"
    #Loop through filelist files, replace old paths with new paths
    foreach($dbfile in $dbfiles){
        $DbFileName = $dbfile.PhysicalName | Split-Path -Leaf
        $ext = [System.IO.Path]::GetExtension($DbFileName)
        $logicalNumber = $($dbfile.LogicalName) -replace '[A-Za-z_]',''
        if ($logicalNumber.Length -gt 0){
            $DbFileName = "$database" + "_" + $logicalNumber + "$ext"
        }else{
            $DbFileName = "$database$ext"
        }
    
        $newfile = [System.IO.Path]::Combine($DataPath, $DbFileName)
        $relocate += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ($dbfile.LogicalName,$newfile)
        Write-Host "Setting Relocate file: $($dbfile.PhysicalName) -> $newfile"
    }

    $srvConn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
    $srvConn.LoginSecure = $false;
    $srvConn.Login = $username
    $srvConn.Password = $password
    $srvConn.ServerInstance = $DBServerInstance

    Write-Host "Killing all process connected to $database"
    # Kill all connections to the database.
    $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server ($srvConn)
    $sqlServer.KillAllProcesses($database)

    Write-Host "--------------------------"
    Write-Host "    Restoring Database"
    Write-Host "--------------------------"
    Write-Host "Database: $database"
    Write-Host "BackupFile: $BackupFile"
    # Restore the database.
    Restore-SqlDatabase -ServerInstance $DBServerInstance `
        -Database $database `
        -RelocateFile $relocate `
        -BackupFile "$BackupFile" `
        -RestoreAction Database `
        -Credential $Cred `
        -ReplaceDatabase -verbose 


}

Export-ModuleMember -Function * -Alias * -WarningAction:SilentlyContinue
