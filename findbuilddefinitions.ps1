# Define the TFS server URL and Personal Access Token
$TfsUrl = "https://tfs.sys.cigna.com/tfs/defaultcollection"
$PersonalAccessToken = "token"

# Encode the PAT with a username for the Authorization header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("user:$PersonalAccessToken"))

Write-Host "Fetching build definitions and updating JSON structure..."

# Read the existing JSON file with project and repository details
$jsonFilePath = "old-projectRepoDetailsTFS2017.json"
if (-Not (Test-Path $jsonFilePath)) {
    Write-Error "JSON file $jsonFilePath not found. Please ensure the file exists."
    exit
}

$projectRepoDetails = Get-Content -Path $jsonFilePath | ConvertFrom-Json

# Initialize an array to store updated project details
$updatedProjectDetails = @()

foreach ($project in $projectRepoDetails) {
    $projectName = $project.ProjectName
    Write-Host "Fetching build definitions for project: $projectName"

    try {
        # Make a REST API call to get the build definitions for the project
        $buildDefinitionsResponse = Invoke-RestMethod -Uri "$TfsUrl/$projectName/_apis/build/definitions?api-version=2.0" -Headers @{
            Authorization = "Basic $base64AuthInfo"
        } -Method Get

        $buildDefinitions = $buildDefinitionsResponse.value | ForEach-Object {
            [PSCustomObject]@{
                BuildDefinitionName = $_.name
                BuildDefinitionId = $_.id
                BuildDefinitionType = if ($_.process.type -eq 2) { "YAML" } else { "Classic" }
                BranchName = $_.repository.Branch
            }
        }

        # Fetch release pipeline definitions for the project
        Write-Host "Fetching release definitions for project: $projectName"
        $releaseDefinitions = @()
        try {
            $releaseDefinitionsResponse = Invoke-RestMethod -Uri "$TfsUrl/$projectName/_apis/release/definitions?api-version=3.0-preview.1" -Headers @{
                Authorization = "Basic $base64AuthInfo"
            } -Method Get

            $releaseDefinitions = $releaseDefinitionsResponse.value | ForEach-Object {
                [PSCustomObject]@{
                    ReleaseDefinitionName = $_.name
                    ReleaseDefinitionId = $_.id
                }
            }
        } catch {
            Write-Error "Failed to fetch release definitions for project: $projectName. Error: $_"
        }

        # Add the build and release definitions to the project details
        $updatedProjectDetails += [PSCustomObject]@{
            ProjectName = $projectName
            Repositories = $project.Repositories
            BuildDefinitions = $buildDefinitions
            ReleaseDefinitions = $releaseDefinitions
        }
    } catch {
        Write-Error "Failed to fetch build definitions for project: $projectName. Error: $_"
    }
}

# Save the updated project details to a new JSON file
$updatedProjectDetails | ConvertTo-Json -Depth 10 | Out-File -FilePath "master-project-and-pipeline.json"

Write-Host "Updated project details saved to master-project-and-pipeline.json"