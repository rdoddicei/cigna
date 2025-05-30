param(
    [Parameter(Mandatory = $true)] [string]$TfsUrl,
    [Parameter(Mandatory = $true)] [string]$GitHubOrg,
    [Parameter(Mandatory = $true)] [string]$JsonFilePath
)

# ========== Tokens ==========
Write-Output "`n=== Reading Tokens and Setting Up Directories ==="

$TfsToken = "---"  # Replace with real PAT
$GitHubToken = "---"  # Replace with real PAT

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
        $rawRepoPath = $repo.RepositoryName
        $repoType = $repo.RepositoryType.ToUpper()

        # === Clean and normalize repo path ===
        $cleanRepoPath = $rawRepoPath -replace "^\$/", ""  # Remove $/ prefix
        $pathParts = $cleanRepoPath -split '/'

        # === Determine GitHub repository name ===
        if ($pathParts.Length -eq 0 -or [string]::IsNullOrWhiteSpace($pathParts[-1])) {
            Write-Output "Invalid repo path format: $rawRepoPath"
            continue
        }

        $repoName = $pathParts[-1]
        $githubRepoName = if ($projectName -eq $repoName) { $projectName } else { "$projectName-$repoName" }

        $localRepoPath = Join-Path -Path $workingDir -ChildPath $githubRepoName

        Write-Output "`n--- Processing Repository: $githubRepoName (Type: $repoType) ---"

        # === Create GitHub Repository ===
        Write-Output "`nCreating GitHub Repository: $githubRepoName"
        $createRepoUri = "https://api.github.com/orgs/$GitHubOrg/repos"
        $repoBody = @{
            name = $githubRepoName
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
            Write-Output "ERROR: Failed to create GitHub repo: $githubRepoName. Skipping this repo."
            Write-Output $_
            continue
        }

        # === Clone TFVC Repository ===
        if ($repoType -eq "TFVC") {
            Write-Output "`nCloning TFVC Repo from TFS: $rawRepoPath"

            if (Test-Path $localRepoPath) {
                Write-Output "Removing existing local directory: $localRepoPath"
                Remove-Item -Recurse -Force -Path $localRepoPath
            }

            # Create temp home directory for git-tfs config
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

            $cloneCmd = "git tfs clone --username patuser --password *** $TfsUrl $rawRepoPath $localRepoPath"
            Write-Output "Executing: $cloneCmd"
            & git tfs clone --username "patuser" --password $TfsToken $TfsUrl $rawRepoPath $localRepoPath
            $cloneExitCode = $LASTEXITCODE

            $env:USERPROFILE = $oldUserProfile
            Remove-Item -Recurse -Force -Path $tempHome

            if ($cloneExitCode -ne 0) {
                Write-Output "ERROR: git-tfs clone failed for $githubRepoName. Skipping push."
                continue
            }

            Write-Output "TFVC repository cloned to: $localRepoPath"

            # === Git Config and Push ===
            git -C $localRepoPath config user.name "tfs-import-bot"
            git -C $localRepoPath config user.email "tfs-import-bot@example.com"

            Write-Output "`nPushing Repo to GitHub"
            Set-Location -Path $localRepoPath
            git remote add origin "https://$GitHubToken@github.com/$GitHubOrg/$githubRepoName.git"
            git push origin --all
            git push origin --tags

            Set-Location -Path $workingDir
            Write-Output "Repository pushed successfully to GitHub: $githubRepoName"

            # === Cleanup ===
            Write-Output "`nCleaning Up Local Repo Directory"
            Remove-Item -Recurse -Force -Path $localRepoPath
        }
        elseif ($repoType -eq "GIT") {
            Write-Output "Git repository migration not implemented yet for $githubRepoName"
        }
        else {
            Write-Output "ERROR: Unknown repo type '$repoType' for $githubRepoName"
        }

        Write-Output "--- Completed migration for: $githubRepoName ---"
    }

    Write-Output "=== Completed project: $projectName ==="
}

# ========== Final Output ==========
Write-Output "`n=== Migration Completed ==="
