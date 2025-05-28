param(
    [Parameter(Mandatory = $true)] [string]$TfsUrl,
    [Parameter(Mandatory = $true)] [string]$GitHubOrg,
    [Parameter(Mandatory = $true)] [string]$JsonFilePath
)

# ==========  Read Tokens and Setup ==========

Write-Output "`n===  Reading Tokens and Setting Up Directories ==="

$TfsToken = "----"
$GitHubToken = "---"

if (-not $TfsToken) { throw "Missing TFS_TOKEN in environment variables." }
if (-not $GitHubToken) { throw "Missing GITHUB_TOKEN in environment variables." }

$workingDir = Join-Path -Path $PWD -ChildPath "repo"
if (-not (Test-Path $workingDir)) {
    Write-Output "Creating working directory at $workingDir"
    New-Item -ItemType Directory -Path $workingDir | Out-Null
} else {
    Write-Output "Working directory already exists at $workingDir"
}

# ========== Read JSON Input ==========

Write-Output "`n=== Reading Input JSON File ==="

if (-not (Test-Path $JsonFilePath)) {
    throw "JSON input file not found: $JsonFilePath"
}

$jsonContent = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json
Write-Output "Loaded JSON with $($jsonContent.Count) project(s)."

# ==========  Process Each Project and Repository ==========

foreach ($project in $jsonContent) {
    $projectName = $project.ProjectName
    $repositories = $project.Repositories

    Write-Output "`n===  Processing Project: $projectName ==="

    foreach ($repo in $repositories) {
        $repoPath = $repo.RepositoryName
        $repoName = ($repoPath -split '/')[ -1 ]
        $repoType = $repo.RepositoryType.ToUpper()
        $tfvcPath = $repoPath
        $localRepoPath = Join-Path -Path $workingDir -ChildPath $repoName

        Write-Output "`n--- Processing Repository: $repoName (Type: $repoType) ---"

        # ==========  Create GitHub Repo ==========

        Write-Output "`n Creating GitHub Repository: $repoName"
        $createRepoUri = "https://api.github.com/orgs/$GitHubOrg/repos"
        $repoBody = @{
            name = $repoName
            visibility = "internal"
            auto_init = $false
        } | ConvertTo-Json -Depth 3

        $headers = @{
            Authorization = "token $GitHubToken"
            Accept = "application/vnd.github.v3+json"
            "User-Agent" = "PowerShell-Script"
        }

        try {
            $response = Invoke-RestMethod -Uri $createRepoUri -Method Post -Headers $headers -Body $repoBody
            Write-Output "GitHub repo created successfully: $($response.full_name)"
        } catch {
            Write-Output "ERROR: Failed to create GitHub repo: $repoName. Skipping this repo."
            Write-Output $_
            continue
        }

        # ==========  Clone TFVC Repository ==========

        if ($repoType -eq "TFVC") {
            Write-Output "`n Cloning TFVC Repo from TFS: $tfvcPath"

            if (Test-Path $localRepoPath) {
                Write-Output "Removing existing local directory: $localRepoPath"
                Remove-Item -Recurse -Force -Path $localRepoPath
            }

            $cloneCmd = "git tfs clone --username user --password *** $TfsUrl $tfvcPath $localRepoPath"
            Write-Output "Executing: $cloneCmd"

            & git tfs clone --username user --password $TfsToken $TfsUrl $tfvcPath $localRepoPath
            if ($LASTEXITCODE -ne 0) {
                Write-Output "ERROR: git-tfs clone failed for $repoName. Skipping push."
                continue
            }

            Write-Output "TFVC repository cloned to: $localRepoPath"

            # ==========  Push to GitHub ==========

            Write-Output "`n Pushing Repo to GitHub"
            Set-Location -Path $localRepoPath

            git remote add origin "https://$GitHubToken@github.com/$GitHubOrg/$repoName.git"
            git push origin --all
            git push origin --tags

            Set-Location -Path $workingDir
            Write-Output "Repository pushed successfully to GitHub: $repoName"

            # ==========  Cleanup ==========

            Write-Output "`n Cleaning Up Local Repo Directory"
            Remove-Item -Recurse -Force -Path $localRepoPath
            Write-Output "Local repo directory removed: $localRepoPath"
        } elseif ($repoType -eq "GIT") {
            Write-Output "Git repository migration not implemented yet for $repoName"
        } else {
            Write-Output "ERROR: Unknown repo type '$repoType' for $repoName"
        }

        Write-Output "--- Completed migration for: $repoName ---"
    }

    Write-Output "=== Completed project: $projectName ==="
}

# ========== Final Output ==========

Write-Output "`n===  Migration Completed  ==="
