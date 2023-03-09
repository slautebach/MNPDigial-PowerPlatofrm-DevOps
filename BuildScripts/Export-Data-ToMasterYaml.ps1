param(
    [Parameter(Position=0)]
    [string]$dataPath = "" # Optionally specify a specific path to process
) 

# Load the Package Data
Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation


Load-PackageData

Load-Module powershell-yaml


$masterDataPath = "$PSScriptRoot\..\ConfigurationData\master"

$xml = [xml](Get-Content -Path "$dataPath\data.xml")
$xmlSchema = [xml](Get-Content -Path "$dataPath\data_schema.xml")



$xml.entities.entity | ForEach-Object{
    $entitiesObj = $_
    Write-Host "Entity Name $($entitiesObj.name)"
    $entitySchema = Select-Xml -Xml $xmlSchema -XPath "/entities/entity[@name='$($entitiesObj.name)']"
    $primaryNameField = $entitySchema.Node.GetAttribute("primarynamefield")
    $primaryIdField = $entitySchema.Node.GetAttribute("primaryidfield")
    Write-Host "Primary Name Field: $primaryNameField"

    $entityDataPath = "$masterDataPath\$($entitiesObj.name)"
    New-Item -ItemType Directory -Force -Path $entityDataPath
    $entitiesObj.records.record | ForEach-Object {
        $recordObj = $_
        $recordId = $recordObj.id
        $recordName = ""
        $entity =[ordered] @{}
        $fieldCount = 0
        $recordObj.field | ForEach-Object {
            $fieldCount++
            $field = $_
            $value = $field.value.Trim()
            $name = $field.name
            $entity[$name] = $value

            # Check if the string is a JSON string, and try to convert it to an object
            # if it works set the object as the value to be yaml serialized.
            try {
                if ($value.StartsWith("{") -and $value.EndsWith("}")) {
                    # catch and log 
                    Write-Host "Converting field $name to a JSON object"
                    $jObj =  ConvertFrom-Json $value 
                    $entity[$name] =  $jObj
                }
            }
            catch {
                # catch and log 
                Write-Host "*** Tried to convert field $name to a JSON object, but failed with error $_."
            }
            if ($field.lookupentity -ne "" -and $field.lookupentity -ne $null) {
                $entity[$field.name] = [ordered]@{
                    value = $field.value;
                    lookupentity = $field.lookupentity;
                    lookupentityname = $field.lookupentityname
                }
            }
        }
        if ($fieldCount -lt 2){
            #only one field (field id) no data so skip extract
            # and prevent us from overwriting good data.
            return
        }

        # set default yaml file name
        $ymlFile = "$entityDataPath\$recordId.yml"
        
        # delete existing file matching the guid
        $filesToDelete = Get-ChildItem -Recurse -Path "$entityDataPath\" | Where {$_.Name.Contains($recordId)}

        
        foreach ($file in $filesToDelete){
            Write-Host "Deleting $($file.FullName)"
            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        }
        # Get the entity primary name value
        $recordName = $entity[$primaryNameField]

        # if null set to ""
        if ($recordName -eq $null){
            $recordName = ""
        }

        # convert invalud filename values so we can use it as a filename
        $recordName = ConvertInvalidFileNames $recordName
        if ($recordName.Length -gt 100){
            # turncate the file to a maximum of 100 characters
            $recordName = $recordName.SubString(0, 100)
        }

        # remove begining and trailing white spaces
        $recordName = $recordName.Trim()

        # if the file starts with "-" prepend "_" to the file name
        if ($recordName.StartsWith("-")){
            $recordName = "_$recordName"
        }

        # if we have record name, prepend it to the yaml filename.
        if ($recordName -ne ""){
            $ymlFile = "$entityDataPath\$recordName.$recordId.yml"
        }
        Write-Host "Updating data yml file: $ymlFile"
        $entity | ConvertTo-Yaml | Out-File -Encoding "UTF8" -FilePath "$ymlFile"
    }
}

