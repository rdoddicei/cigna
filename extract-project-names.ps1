# User inputs
$collectionUrl = "https://tfs.sys.cigna.com/tfs/DefaultCollection"
$personalAccessToken = "***********"

# Prepare basic auth header with PAT
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("user:$personalAccessToken"))
$headers = @{ Authorization = "Basic $base64AuthInfo" }

# API version
$apiVersion = "2.0"

# Get all projects in one request (no pagination)
$uri = "$collectionUrl/_apis/projects?api-version=$apiVersion"

try {
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    $allProjects = $response.value
}
catch {
    Write-Error "Failed to get projects: $_"
    exit 1
}

# Prepare output list with ProjectName, ProjectType (Git/TFVC), CollectionUrl
$output = @()

foreach ($project in $allProjects) {
    $projectId = $project.id
    $projectName = $project.name

    # Get Git repositories for this project
    $gitReposUri = "$collectionUrl/$projectId/_apis/git/repositories?api-version=$apiVersion"
    try {
        $gitReposResponse = Invoke-RestMethod -Uri $gitReposUri -Headers $headers -Method Get
        $gitRepos = $gitReposResponse.value
    }
    catch {
        Write-Warning "Could not fetch Git repos for project ${projectName}: $_"
        $gitRepos = @()
    }

    if ($gitRepos.Count -gt 0) {
        $projectType = "Git"
        $repositories = $gitRepos | ForEach-Object {
            @{
                RepositoryName = $_.name
                RepositoryType = "Git"
            }
        }
    }
    else {
        $projectType = "TFVC"
        $repositories = @(@{
            RepositoryName = "$/$projectName"
            RepositoryType = "TFVC"
        })
    }

    $output += @{
        ProjectName = $projectName
        ProjectType = $projectType
        CollectionUrl = $collectionUrl
        Repositories = $repositories
    }
}

# Convert output to JSON and save to file
$output | ConvertTo-Json -Depth 5 | Out-File -FilePath "TfsProjectsList.json" -Encoding utf8

Write-Host "Project list saved to TfsProjectsList.json"
