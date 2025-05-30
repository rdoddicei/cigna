param(
    [Parameter(Mandatory = $true)] [string]$TfsUrl,
    [Parameter(Mandatory = $true)] [string]$GitHubOrg,
    [Parameter(Mandatory = $true)] [string]$JsonFilePath
)

# ========== Tokens ==========
Write-Output "`n=== Reading Tokens and Setting Up Directories ==="

$TfsToken = "--"
$GitHubToken = "--"

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

            # --- Create temp home directory with .gitconfig for git-tfs user config ---
            $tempHome = Join-Path $env:TEMP "git-tfs-temp-home-$([guid]::NewGuid())"
            New-Item -ItemType Directory -Path $tempHome | Out-Null

            $tempGitConfigPath = Join-Path $tempHome ".gitconfig"
            @"
[user]
    name = tfs-import-bot
    email = tfs-import-bot@example.com
"@ | Out-File -FilePath $tempGitConfigPath -Encoding utf8

            $oldUserProfile = $env:USERPROFILE
            $env:USERPROFILE = $tempHome

            Write-Output "Temporary USERPROFILE set to $tempHome"

            # --- Run git tfs clone ---
            $cloneCmd = "git tfs clone --username patuser --password *** $TfsUrl $tfvcPath $localRepoPath"
            Write-Output "Executing: $cloneCmd"

            & git tfs clone --username "patuser" --password $TfsToken $TfsUrl $tfvcPath $localRepoPath

            $cloneExitCode = $LASTEXITCODE

            # --- Reset USERPROFILE ---
            $env:USERPROFILE = $oldUserProfile

            # --- Cleanup temp home ---
            Remove-Item -Recurse -Force -Path $tempHome

            if ($cloneExitCode -ne 0) {
                Write-Output "ERROR: git-tfs clone failed for $repoName. Skipping push."
                continue
            }

            Write-Output "TFVC repository cloned to: $localRepoPath"

            # ========== Set Local Git Config ==========
            git -C $localRepoPath config user.name "tfs-import-bot"
            git -C $localRepoPath config user.email "tfs-import-bot@example.com"
            Write-Output "Git config user.name and user.email set locally."

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
