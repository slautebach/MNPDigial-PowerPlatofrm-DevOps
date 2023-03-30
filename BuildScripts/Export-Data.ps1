param(
    [Parameter(Mandatory=$true)]
	[string] $targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
	[string] $solutionName, # Solution Views Names
    [string] $schemaFileName = "$PSScriptRoot\..\ConfigurationData\Configuration.xml", # path to schema file
    [string] $globalViewName,
    [string] $appId = "", # optional app id to connect to dataverse
	[string] $clientSecret = "", #  client secret for the app id
    [switch] $Force # if the package enables the component to build
) 

Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking
Import-Module "$PSScriptRoot\PS-Modules\Dataverse-API.psm1" -Force  -DisableNameChecking
Load-Module  CrmDataPackager
Load-Module Microsoft.Xrm.DevOps.Data.PowerShell


# Log Script Invcation Details
LogInvocationDetails $MyInvocation


SetPACConnections  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret


if (!$Force -and !$PackageData.BuildPackages.Data){
	Write-Host "Data Export is not enabled in package.yml"
	exit
}

# if solution is not specified, then get it from the version.json file.
if ($solutionName -eq ""){
	$solutionName = $PackageData.SolutionName
}

# set the global shared filter view if not specified from the build variables
if ($globalViewName -eq ""){
	$globalViewName = $PackageData.GlobalSharedFilterView
}


$ConfigDataExtractPath = "$PSScriptRoot\..\ConfigurationData\SolutionBuilds\$solutionName\"

New-Item -ItemType Directory -Force -Path "$PSScriptRoot\..\ConfigurationData\SolutionBuilds\" -ErrorAction SilentlyContinue | Out-Null

$zipDataFile = "$PSScriptRoot\..\ConfigurationData\SolutionBuilds\$solutionName-Data.zip"



Write-Host ""
Write-Host "=================================================================="
Write-Host "Connecting to Dataverse API"
Write-Host "=================================================================="
ConnectDataverseApi  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret


Write-Host ""
Write-Host "*******************************************************************"
Write-Host "Updateing Schema File $schemaFileName"
Write-Host "*******************************************************************"
. "$PSScriptRoot\..\ConfigurationData\UpdateConfigurationXml.ps1"  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret -schemaFileName $schemaFileName -excludeEntities @("rp_fileattachmentconfig")
Write-Host "*******************************************************************"
Write-Host "*******************************************************************"
Write-Host "*******************************************************************"


# add any system attributes we should exclude from the extract that are not needed
$excludeAttributes = @("createdon", "modifiedon", "overriddencreatedon", "overriddenmodifiedon", "versionnumber", "createdby", "modifiedby")
# Given a path to a schema file, load it to build all the fetches
# for all the entitites defined within it.
# If There are any shared queries in CRM, it extracts the filter conditions
# and uses it to filter the records.
function Get-Fetches{
    param(
        [Parameter(Position=0,mandatory=$true)]
        [string]$xmlSchemaFile, #The root path of the package deployer
        $fetchQueries
    ) 
    Write-Host "Loading Schema File: $xmlSchemaFile"
    [xml]$xml = Get-Content "$xmlSchemaFile"

    $nodes = Select-Xml "/entities/entity" $xml
    $fetches = @()
    $nodes | ForEach-Object {
        #$_.Node.'#text'
        $attributes = "";
    
        $entityLogicalName = $_.Node.Name
               
        $_.Node.SelectNodes("fields/field/@name") | ForEach-Object {
            #Write-Host $_.value
           if ($excludeAttributes.Contains($_.value)){
               Write-Host "    Excluding attirubte $($_.value) from extract."
               return;
           }
           $attributes = "$attributes`n`t<attribute name='$($_.value)' />";
        }

        # Get all ther filters for the current entity across all fetches
        $fetchFilterRecords = $fetchQueries | Where-Object -FilterScript { $_.returnedtypecode_Property.Value -eq $entityLogicalName}

       
        
        # If there are no entity records specified by the data views skip.
        if ($fetchFilterRecords -eq $null){
            Write-Host "Skipping extract for Entity: $entityLogicalName does not contain any user views to filter data."
            return;
        }
        Write-Host "Processing fetch for Entity: $entityLogicalName."
        $hasFilter = $false
        # For all fitlers for every fetch for the current entity, union them into an OR and add the attributes
        $filterXml = "`t<filter type='or'>`n";
        $fetchFilterRecords | ForEach-Object {
            $fetchFilterXmlRecord = $_
            $fetchFilterXml = [xml]$fetchFilterXmlRecord.fetchxml
            $filter = $fetchFilterXml.SelectSingleNode("fetch/entity/filter") 
            $filterXml = "$filterXml `n`n<!-- Start of $($fetchFilterXmlRecord.name) -->`n`n $($filter.InnerXml)`n`n<!-- End of $($fetchFilterXmlRecord.name) -->`n`n"
        }
        $filterXml = "$filterXml `n`t</filter>";

        # build the fetch we will use for the entity with the attributes and the all the "or" filters combined
        $fetch = "<fetch>`n`t<entity name='$($entityLogicalName)'>`n $attributes `n $filterXml `n</entity>`n</fetch>"
        $fetches +=  $fetch;  
    
    }
    return $fetches
}

 $fetch=@"
 <fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>
  <entity name='userquery' >
   <attribute name='name' />
   <attribute name='fetchxml' />
    <attribute name='returnedtypecode' />
    <order attribute='name' descending='false' />
      <filter type='or'>
        <condition attribute='name' operator='eq' value='$solutionName' />
        <condition attribute='name' operator='eq' value='$globalViewName' />
      </filter>
  </entity>
</fetch>
"@

Write-Host ""
Write-Host "=================================================================="
Write-Host "Fetch for finding Shared Views"
Write-Host "=================================================================="
Write-Host $fetch

# get the results, and if non are found return null
$dataFilterFetchResults = get-crmrecordsbyfetch  -conn $Conn -Fetch $fetch

Write-Host "Retrieved $($dataFilterFetchResults.CrmRecords.Count) Data Queries for: '$solutionName' and '$globalViewName'"
$fetchQueries = $dataFilterFetchResults.CrmRecords


Write-Host ""
Write-Host "=================================================================="
Write-Host "Generate the Entity Fetches based on the $schemaFileName"
Write-Host "=================================================================="
# From the scheama files convert them into all fetch queries
$allFetches = Get-Fetches -xmlSchemaFile $schemaFileName -fetchQueries $fetchQueries




Write-Host ""
Write-Host "=================================================================="
Write-Host "Get N2N Queries"
Write-Host "=================================================================="
# Get all Relationship Queries
 $n2nUserQueries=@"
 <fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>
  <entity name='userquery' >
    <attribute name='name' />
   <attribute name='fetchxml' />
    <attribute name='returnedtypecode' />
    <order attribute='name' descending='false' />
      <filter type='or'>
        <condition attribute='name' operator='like' value='$solutionName-N2N%' />
        <condition attribute='name' operator='like' value='$globalViewName-N2N%' />
      </filter>
  </entity>
</fetch>
"@

Write-Host "Fetch for N2N Shared Views"
Write-Host $n2nUserQueries



# get the results, and if non are found return null
$n2nResults = get-crmrecordsbyfetch  -conn $Conn -Fetch $n2nUserQueries
$n2nFetchQueries = $n2nResults.CrmRecords

Write-Host "Retrieved $($n2nResults.CrmRecords.Count) N2N Data Queries for: '$solutionName' and '$globalViewName'"


Write-Host "Add N2N Fetches to all fetches..."
# From the N2N relationship queries extract the fetch and build it so that it works.
foreach ($n2nFetchRecord in $n2nResults.CrmRecords)
{
    $fetchFilterXml = [xml]$n2nFetchRecord.fetchxml
    $linkEntityNode = $fetchFilterXml.SelectSingleNode("fetch/entity/link-entity") 
    $relatedEntity = $fetchFilterXml.SelectSingleNode("fetch/entity/link-entity/link-entity") 
    if ($relatedEntity -eq $null){
        Write-Error "Unable to process fetch: "
        Write-Host $n2nFetchRecord.fetchxml
        exit
    }
    $attribute = $fetchFilterXml.CreateElement("attribute")
    $attribute.SetAttribute("name", $relatedEntity.Attributes["to"].Value)
    $linkEntityNode.AppendChild($attribute)
    $allFetches += $fetchFilterXml.OuterXml
}

if ($allFetches.Length -eq 0){
    Write-Host ""
    Write-Host "===================================================================================================="
    Write-Host "0 Data and N2N fetches found for queries identified as: '$solutionName' and '$globalViewName'." 
    Write-Host "===================================================================================================="
    throw "No Data to Query to export data.  Please make sure the user queries are configured and shared correctly."   
    exit
}



Write-Host ""
Write-Host "=================================================================="
Write-Host "Configuring Plugins to Disable"
Write-Host "=================================================================="
$DisablePlugins = @{};
Write-Host "Going to Extract data for the following Fetch Queries:"
# Foreach of all the fetches.  Load it as an xml
# Format with indents for pretty printing for debugging purposes.
 $allFetches| ForEach-Object {
     $fetchXml = [xml]$_
     $entity = $fetchXml.SelectSingleNode("fetch/entity") 
     $entityLogicalName = $entity.Attributes["name"].Value

     Write-Host "================================== $entityLogicalName ==================================";
     
     $doc=New-Object System.Xml.XmlDataDocument
     $doc.LoadXml($_)
     $sw=New-Object System.Io.Stringwriter
     $writer=New-Object System.Xml.XmlTextWriter($sw)
     $writer.Formatting = [System.Xml.Formatting]::Indented
     $doc.WriteContentTo($writer)
     $prettyXml = $sw.ToString()
     
     Write-Host "Fetch:";
     Write-Host $prettyXml;

     # Run the fetch to get the top 1 record.  If one record exists
     # Add it to the disable plugins list for that entity
     # we need to check that we are extracting at least on record of each entity
     # otherwise if we specify an entity to disable a plugin, then when running
     # Get-CrmDataPackage below it will throw an exception.
     $fetchResult = get-crmrecordsbyfetch  -conn $Conn -Fetch $_ -TopCount 1
     $fetchResult.CrmRecords| ForEach-Object {
         $entityName = $_.LogicalName
         if ($PackageData.CrmDataPackageConfig.DisablePlugins -and $PackageData.CrmDataPackageConfig.DisablePlugins.ContainsKey($entityName)) {
             # if the variables.json specify a value, then we will use that value
             $DisablePlugins[$entityName] = $PackageData.CrmDataPackageConfig.DisablePlugins[$entityName]
         } 
         else {
             # disable plugin by default
             $DisablePlugins[$entityName] = $true
         }
     }
   
     Write-Host "=================================================================================";
     Write-Host "";
     Write-Host "";
}

# Update the Disable Plugins List with that that we are extracting to prevent Get-CrmDataPackage from throwing an exception.
$PackageData.CrmDataPackageConfig.DisablePlugins = $DisablePlugins
# Write the updated Crm Data Package Configuration to console

Write-Host ""
Write-Host "=================================================================="
Write-Host "Crm Data Package Configuration:"
Write-Host "=================================================================="
Write-HashTable -hashTable $PackageData.CrmDataPackageConfig

Remove-Item $zipDataFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=================================================================="
Write-Host "Extracting Fetchs from Dynamics to $zipDataFile"
Write-Host "=================================================================="
# Extract the data
try{
    if ($PackageData.CrmDataPackageConfig.Identifiers.Count -gt 0 -and $PackageData.CrmDataPackageConfig.DisablePlugins.Count -gt 0){
        Write-Host "Extract with Identifiers and disable plugins"
        Write-Object $PackageData.CrmDataPackageConfig.DisablePlugins
        Write-Object $PackageData.CrmDataPackageConfig.Identifiers
        Get-CrmDataPackage -Conn $Conn -Fetches $allFetches -Identifiers $PackageData.CrmDataPackageConfig.Identifiers -DisablePlugins $PackageData.CrmDataPackageConfig.DisablePlugins | Export-CrmDataPackage -ZipPath $zipDataFile
    }
    elseif ($PackageData.CrmDataPackageConfig.Identifiers.Count -gt 0 -and $PackageData.CrmDataPackageConfig.DisablePlugins.Count -eq 0){
        Write-Host "Extract with Identifiers"
        Write-Object $PackageData.CrmDataPackageConfig.Identifiers
        Get-CrmDataPackage -Conn $Conn -Fetches $allFetches -Identifiers $PackageData.CrmDataPackageConfig.Identifiers | Export-CrmDataPackage -ZipPath $zipDataFile
    }
    elseif ($PackageData.CrmDataPackageConfig.Identifiers.Count -eq 0 -and $PackageData.CrmDataPackageConfig.DisablePlugins.Count -gt 0){
        Write-Host "Extract with disable plugins"
        Write-Object $PackageData.CrmDataPackageConfig.DisablePlugins
        Get-CrmDataPackage -Conn $Conn -Fetches $allFetches -DisablePlugins $PackageData.CrmDataPackageConfig.DisablePlugins | Export-CrmDataPackage -ZipPath $zipDataFile
    }
    else {
        Write-Host "Extract without identifers and no plugins disabled"
        Get-CrmDataPackage -Conn $Conn -Fetches $allFetches | Export-CrmDataPackage -ZipPath $zipDataFile
    }
}
catch {
    Write-Host "Get-CrmDataPackage threw an exception"
    Write-Host "This could be due to a bug, where if the list of Identifiers or Disabled plugins list an entity"
    Write-Host "that does not end up in the data package an error occurs."   
    Write-Host "Please validate the Identifiers and Disabled Plugins list." 
    throw $_
}

Write-Host ""
Write-Host "=================================================================="
Write-Host "Processing $zipDataFile"
Write-Host "=================================================================="

# Expand the Data through the Adoxio Dev Ops Module.
$folder = $zipDataFile -replace ".zip",""
Write-Host "Extracting $zipDataFile to: '$ConfigDataExtractPath'"

# cleare out and deelete the directory
Remove-Item -Force -Recurse -Path $ConfigDataExtractPath -ErrorAction SilentlyContinue

# unzip the configuration data
Expand-Archive -Path $zipDataFile -DestinationPath $ConfigDataExtractPath

#cleanup remove the zip file whendone.
Remove-Item $zipDataFile -ErrorAction SilentlyContinue


Write-Host ""
Write-Host "*******************************************************************"
Write-Host "Converting Data To YAML for PR"
Write-Host "*******************************************************************"
. "$PSScriptRoot\Export-Data-ToMasterYaml.ps1" -dataPath $ConfigDataExtractPath
Write-Host "*******************************************************************"
Write-Host "*******************************************************************"
Write-Host "*******************************************************************"
