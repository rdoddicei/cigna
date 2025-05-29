param(
    [Parameter(Mandatory = $true)] [string]$TfsUrl,
    [Parameter(Mandatory = $true)] [string]$GitHubOrg,
    [Parameter(Mandatory = $true)] [string]$JsonFilePath
)

# Set tokens
$TfsToken = "---"
$GitHubToken = "---"

if (-not $TfsToken) { throw "Missing TFS_TOKEN in script." }
if (-not $GitHubToken) { throw "Missing GITHUB_TOKEN in script." }

# Create working directory
$workingDir = Join-Path -Path $PWD -ChildPath "repo"
if (-not (Test-Path $workingDir)) {
    New-Item -ItemType Directory -Path $workingDir | Out-Null
}

# Load input JSON
if (-not (Test-Path $JsonFilePath)) {
    throw "JSON input file not found: $JsonFilePath"
}

$jsonContent = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json
Write-Output "Loaded $($jsonContent.Count) project(s) from input JSON"

# Process each project and its repositories
foreach ($project in $jsonContent) {
    $projectName = $project.ProjectName
    $repositories = $project.Repositories

    Write-Output "`nProcessing Project: $projectName"

    foreach ($repo in $repositories) {
        $repoPath = $repo.RepositoryName
        $repoType = $repo.RepositoryType.ToUpper()

        $cleanRepoPath = $repoPath -replace "^\$/", ""
        $pathParts = $cleanRepoPath -split '/'

        if ($pathParts.Length -lt 2) {
            Write-Output "Invalid repo path format: $repoPath"
            continue
        }

        $projectPart = $pathParts[0]
        $repoName = ($pathParts[-1])
        $repoSubPath = ($pathParts | Select-Object -Skip 1) -join '/'
        $tfsGitUrl = "$TfsUrl/$projectPart/_git/$repoSubPath"

        $localRepoPath = Join-Path -Path $workingDir -ChildPath $repoName
        Write-Output "`nProcessing Repository: $repoName (Type: $repoType)"

        # Create GitHub repository
        $createRepoUri = "https://api.github.com/orgs/$GitHubOrg/repos"
        $repoBody = @{
            name = $repoName
            visibility = "internal"
            auto_init = $false
        } | ConvertTo-Json -Depth 3

        $headers = @{
            Authorization = "token $GitHubToken"
            Accept = "application/vnd.github.v3+json"
            "User-Agent" = "PowerShell-MigrationScript"
        }

        try {
            $response = Invoke-RestMethod -Uri $createRepoUri -Method Post -Headers $headers -Body $repoBody
            Write-Output "GitHub repo created: $($response.full_name)"
        } catch {
            Write-Output "Skipping repo: $repoName - GitHub repo may already exist or failed to create"
            continue
        }

        if ($repoType -eq "GIT") {
            if (Test-Path $localRepoPath) {
                Remove-Item -Recurse -Force -Path $localRepoPath
            }

            Write-Output "Cloning from TFS: $tfsGitUrl"

            # Use the same logic as tfgit-to-github.ps1 for authentication
            $secureCloneUrl = $tfsGitUrl -replace "^https://", "https://$TfsToken@"
            $maskedCloneUrl = $secureCloneUrl -replace $TfsToken, '***'
            Write-Output "Cloning from TFS URL: $maskedCloneUrl"

            try {
                git -c http.sslVerify=false clone --mirror $secureCloneUrl $localRepoPath
            } catch {
                Write-Output "Git clone failed for $repoName - $_"
                continue
            }

            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $localRepoPath)) {
                Write-Output "Git clone failed. Skipping $repoName"
                continue
            }

            Write-Output "Pushing to GitHub: $repoName"
            try {
                Set-Location -Path $localRepoPath

                git remote remove origin -ErrorAction SilentlyContinue
                git remote add origin "https://x-access-token:$GitHubToken@github.com/$GitHubOrg/$repoName.git"

                git push --mirror
            } catch {
                Write-Output "Push to GitHub failed for $repoName - $_"
                continue
            } finally {
                Set-Location -Path $workingDir
                Remove-Item -Recurse -Force -Path $localRepoPath
                Write-Output "Cleaned local repo: $repoName"
            }

        } elseif ($repoType -eq "TFVC") {
            Write-Output "Skipping TFVC repo: $repoName - Not supported"
        } else {
            Write-Output "Unknown repo type: $repoType"
        }

        Write-Output "Done: $repoName"
    }

    Write-Output "`nCompleted Project: $projectName"
}

Write-Output "`nAll repositories processed."
