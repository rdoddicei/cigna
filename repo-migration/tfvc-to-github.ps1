param(
    [Parameter(Mandatory = $true)] [string]$TfsUrl,
    [Parameter(Mandatory = $true)] [string]$GitHubOrg,
    [Parameter(Mandatory = $true)] [string]$JsonFilePath
)

# ========== Tokens ==========
Write-Output "`n=== Reading Tokens and Setting Up Directories ==="

$TfsToken = "<YOUR_TFS_PAT_HERE>"       # ⚠️ Replace with your actual TFS PAT
$GitHubToken = "<YOUR_GITHUB_PAT_HERE>" # ⚠️ Replace with your actual GitHub PAT

if (-not $TfsToken) { throw "Missing TFS_TOKEN." }
if (-not $GitHubToken) { throw "Missing GITHUB_TOKEN." }

# ========== Working Directory ==========
$workingDir = Join-Path -Path $PWD -ChildPath "repo"
if (-not (Test-Path $workingDir)) {
    Write-Output "Creating working directory at $workingDir"
    New-Item -ItemType Directory -Path $workingDir | Out-Null
} else {
    Write-Output "Working directory already exists at $workingDir"
}

# ========== Read JSON ==========
Write-Output "`n=== Reading Input JSON File ==="
if (-not (Test-Path $JsonFilePath)) {
    throw "JSON input file not found: $JsonFilePath"
}

$jsonContent = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json
Write-Output "Loaded JSON with $($jsonContent.Count) project(s)."

# ========== Process Each Project ==========
foreach ($project in $jsonContent) {
    $projectName = $project.ProjectName
    $repositories = $project.Repositories

    Write-Output "`n=== Processing Project: $projectName ==="

    foreach ($repo in $repositories) {
        $repoPath = $repo.RepositoryName
        $repoName = ($repoPath -split '/')[ -1 ]
        $repoType = $repo.RepositoryType.ToUpper()
        $tfvcPath = $repoPath
        $localRepoPath = Join-Path -Path $workingDir -ChildPath $repoName

        Write-Output "`n--- Processing Repository: $repoName (Type: $repoType) ---"

        # ========== Create GitHub Repo ==========
        Write-Output "`nCreating GitHub Repository: $repoName"
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

        # ========== Clone TFVC Repository ==========
        if ($repoType -eq "TFVC") {
            Write-Output "`nCloning TFVC Repo from TFS: $tfvcPath"

            if (Test-Path $localRepoPath) {
                Write-Output "Removing existing local directory: $localRepoPath"
                Remove-Item -Recurse -Force -Path $localRepoPath
            }

            # ----- TEMP GIT CONFIG -----
            $tempGitConfigDir = Join-Path $env:TEMP "temp_gitconfig_$repoName"
            $gitConfigFile = Join-Path $tempGitConfigDir "gitconfig"

            if (-not (Test-Path $tempGitConfigDir)) {
                New-Item -ItemType Directory -Path $tempGitConfigDir | Out-Null
            }

            git config --file $gitConfigFile user.name "tfs-import-bot"
            git config --file $gitConfigFile user.email "tfs-import-bot@example.com"
            $env:GIT_CONFIG_GLOBAL = $gitConfigFile

            Write-Output "Temporary Git config created and GIT_CONFIG_GLOBAL set."

            # ----- GIT TFS CLONE -----
            $cloneCmd = "git tfs clone --username patuser --password *** $TfsUrl $tfvcPath $localRepoPath"
            Write-Output "Executing: $cloneCmd"

            & git tfs clone --username "patuser" --password $TfsToken $TfsUrl $tfvcPath $localRepoPath

            # Cleanup temp git config
            $env:GIT_CONFIG_GLOBAL = $null
            Remove-Item -Force -Path $gitConfigFile -ErrorAction SilentlyContinue
            Remove-Item -Recurse -Force -Path $tempGitConfigDir -ErrorAction SilentlyContinue

            if ($LASTEXITCODE -ne 0) {
                Write-Output "ERROR: git-tfs clone failed for $repoName. Skipping push."
                continue
            }

            Write-Output "TFVC repository cloned to: $localRepoPath"

            # ========== Push to GitHub ==========
            Write-Output "`nPushing Repo to GitHub"
            Set-Location -Path $localRepoPath

            git remote add origin "https://$GitHubToken@github.com/$GitHubOrg/$repoName.git"
            git push origin --all
            git push origin --tags

            Set-Location -Path $workingDir
            Write-Output "Repository pushed successfully to GitHub: $repoName"

            # ========== Cleanup ==========
            Write-Output "`nCleaning Up Local Repo Directory"
            Remove-Item -Recurse -Force -Path $localRepoPath
            Write-Output "Local repo directory removed: $localRepoPath"
        }
        elseif ($repoType -eq "GIT") {
            Write-Output "Git repository migration not implemented yet for $repoName"
        }
        else {
            Write-Output "ERROR: Unknown repo type '$repoType' for $repoName"
        }

        Write-Output "--- Completed migration for: $repoName ---"
    }

    Write-Output "=== Completed project: $projectName ==="
}

# ========== Final Output ==========
Write-Output "`n=== Migration Completed ==="
