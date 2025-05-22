$TfsUrl = "https://tfs.sys.cigna.com/tfs/defaultcollection"
$PersonalAccessToken = "token"

# Encode the PAT with a username for the Authorization header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("user:$PersonalAccessToken"))

Write-Host "Listing projects and repositories in $TfsUrl..."

# Make a REST API call to get the list of projects
$projectsResponse = Invoke-RestMethod -Uri "$TfsUrl/_apis/projects?api-version=2.0" -Headers @{
    Authorization = "Basic $base64AuthInfo"
} -Method Get

$projects = $projectsResponse.value

# Initialize an array to store project and repository details
$projectRepoDetails = @()

foreach ($project in $projects) {
    $projectName = $project.name
    Write-Host "Fetching repositories for project: $projectName"

    try {
        # Make a REST API call to get the Git repositories for the project
        $reposResponse = Invoke-RestMethod -Uri "$TfsUrl/$($project.id)/_apis/git/repositories?api-version=2.0" -Headers @{
            Authorization = "Basic $base64AuthInfo"
        } -Method Get

        $repositories = $reposResponse.value

        if (-not $repositories) {
            Write-Warning "No Git repositories found for project: $projectName. Checking for TFVC repositories."

            $projectRootPath = "$/" + $projectName

            # Check for TFVC repositories (classic type)
            $tfvcResponse = Invoke-RestMethod -Uri "$TfsUrl/$($project.id)/_apis/tfvc/items?scopePath=$projectRootPath" -Headers @{
                Authorization = "Basic $base64AuthInfo"
            } -Method Get

            $repositories = $tfvcResponse.value | ForEach-Object {
                [PSCustomObject]@{
                    name = $_.path
                    isTfvc = $true
                }
            }
        }

        # Add project and repository details to the array
        $projectRepoDetails += [PSCustomObject]@{
            ProjectName = $projectName
            Repositories = $repositories | ForEach-Object {
                [PSCustomObject]@{
                    RepositoryName = $_.name
                    RepositoryType = if ($_.isTfvc) { "TFVC" } else { "Git" }
                }
            }
        }
    } catch {
        Write-Error "Failed to fetch repositories for project: $projectName. Error: $_"
    }
}

# Save the project and repository details to a JSON file
$projectRepoDetails | ConvertTo-Json -Depth 10 | Out-File -FilePath "projectRepoDetailsTFS2017.json"

Write-Host "Project and repository details saved to projectRepoDetailsTFS2017.json"

# Call findbuilddefinitions.ps1 to fetch build and release definitions
Write-Host "Calling findbuilddefinitions.ps1 to fetch build and release definitions..."
& "$PSScriptRoot/findbuilddefinitions.ps1"

