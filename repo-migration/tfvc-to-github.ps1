# -------------------------------
# Configuration and Environment
# -------------------------------
$tfsPat = $env:TFS_PAT
$githubPat = $env:GITHUB_PAT

if (-not $tfsPat -or -not $githubPat) {
    Write-Error "Environment variables TFS_PAT and GITHUB_PAT must be set."
    exit 1
}

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("user:$tfsPat"))

$organization = "https://tfs.sys.cigna.com/tfs/DefaultCollection"
$destinationOrg = "cigna-group-infrastructure-services"

$workspaceRoot = "C:\TempMigration"

# Log file path
$logFile = Join-Path $workspaceRoot "conversionlog.txt"

# Disable SSL verification globally for Git (if necessary)
git config --global http.sslVerify false

# Set TFS PAT environment variable for git-tfs
[System.Environment]::SetEnvironmentVariable("GIT_TFS_PAT", $tfsPat, [System.EnvironmentVariableTarget]::User)

# Ensure workspace root exists
if (-not (Test-Path -Path $workspaceRoot)) {
    New-Item -ItemType Directory -Force -Path $workspaceRoot | Out-Null
}

# -------------------------------
# Load JSON project-repo mapping
# -------------------------------
$projectJsonPath = "$env:GITHUB_WORKSPACE\repo-migration\projectRepoDetailsTFS2017.json"

if (-not (Test-Path -Path $projectJsonPath)) {
    Write-Error "JSON file not found at $projectJsonPath"
    exit 1
}

$projectData = Get-Content -Raw $projectJsonPath | ConvertFrom-Json

# -------------------------------
# Helper: Log function
# -------------------------------
function Log {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $message"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

# -------------------------------
# Create GitHub repository
# -------------------------------
function Create-GitHubRepo {
    param([string]$repoName)

    $url = "https://api.github.com/orgs/$destinationOrg/repos"

    $body = @{
        name        = $repoName
        visibility  = "internal"
        description = "Migrated from TFS TFVC: $repoName"
    } | ConvertTo-Json -Depth 3

    $headers = @{
        Authorization = "token $githubPat"
        "User-Agent"  = "TFS-to-GitHub-Migration-Script"
        Accept        = "application/vnd.github+json"
        "Content-Type"= "application/json"
    }

    try {
        Log "POST $url with repo name '$repoName'"
        Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ErrorAction Stop | Out-Null
        Log "✅ Created GitHub repo: $repoName"
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.Value__
        $responseStream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $responseBody = $reader.ReadToEnd()
        Log "❌ Failed to create GitHub repo $repoName - Status: $statusCode, Response: $responseBody"

        if ($statusCode -eq 422 -and $responseBody -match "already exists") {
            Log "⚠️ Repo $repoName likely already exists. Continuing..."
            return $true
        }

        return $false
    }
}

# -------------------------------
# Main Migration Loop
# -------------------------------
foreach ($project in $projectData) {
    if (-not $project -or -not $project.ProjectName) {
        Log "Skipping invalid project entry"
        continue
    }

    $projectName = $project.ProjectName.Trim()
    Log "`nProcessing project: $projectName"

    foreach ($repo in $project.Repositories) {
        if ($repo.RepositoryType -ne "TFVC") {
            Log "Skipping non-TFVC repository: $($repo.RepositoryName)"
            continue
        }

        $tfvcPath = $repo.RepositoryName
        $repoNameRaw = ($tfvcPath -split '/')[-1] -replace '[^\w\-]', '-'
        $repoPath = Join-Path -Path $workspaceRoot -ChildPath $repoNameRaw

        # Create GitHub repo first
        $created = Create-GitHubRepo -repoName $repoNameRaw
        if (-not $created) {
            Log "Skipping repo due to GitHub creation failure: $repoNameRaw"
            continue
        }

        # Clean existing directory
        if (Test-Path -Path $repoPath) {
            Log "Removing existing directory: $repoPath"
            Remove-Item -Recurse -Force -Path $repoPath
        }

        # Create directory for cloning
        New-Item -ItemType Directory -Force -Path $repoPath | Out-Null

        # Clone TFVC repo with git-tfs (disable ssl verification)
        $gitTfsCmd = "git tfs clone $organization `"$tfvcPath`" `"$repoPath`" --branches=auto --username=PersonalAccessToken --password=$tfsPat --no-ssl-verify"
        Log "Executing: $gitTfsCmd"

        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "cmd.exe"
        $processInfo.Arguments = "/c $gitTfsCmd"
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        $stdOut = $process.StandardOutput.ReadToEnd()
        $stdErr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        Log "git-tfs output: $stdOut"
        if ($stdErr) { Log "git-tfs errors: $stdErr" }

        if (-not (Test-Path -Path (Join-Path $repoPath ".git"))) {
            Log "❌ Clone failed, no .git folder at $repoPath"
            continue
        }

        # Push to GitHub
        Push-Location $repoPath

        # Remove existing origin remote if exists
        $originExists = git remote | Select-String -Pattern "^origin$"
        if ($originExists) {
            git remote remove origin
            Log "Removed existing 'origin' remote"
        }

        $remoteUrl = "https://$githubPat@github.com/$destinationOrg/$repoNameRaw.git"
        git remote add origin $remoteUrl
        Log "Added 'origin' remote: $remoteUrl"

        Log "Pushing all branches and tags to GitHub..."
        git push -u origin --all
        git push origin --tags

        Log "Running git tfs cleanup"
        git tfs cleanup

        Pop-Location
    }
}

Log "✅ Migration completed successfully!"
