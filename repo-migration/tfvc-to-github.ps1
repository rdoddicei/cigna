# TFS and GitHub Personal Access Tokens
$tfsPat = $env:TFS_PAT
$githubPat = $env:GITHUB_PAT

# Encode the TFS PAT for the Authorization header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("user:$tfsPat"))

$organization = "https://tfs.sys.cigna.com/tfs/DefaultCollection"
$destinationorganization = "cigna-group-infrastructure-services"
Write-Host "$env:GITHUB_WORKSPACE"
$ProjectListJsonPath = "$env:GITHUB_WORKSPACE\repo-migration\projectRepoDetailsTFS2017.json" # Replace with correct PATH

# Read and parse the JSON file
if (-not (Test-Path -Path $ProjectListJsonPath)) {
    Write-Host "Error: JSON file not found at $ProjectListJsonPath" -ForegroundColor Red
    exit 1
}

$projectData = Get-Content -Raw $ProjectListJsonPath | ConvertFrom-Json
$results = @()
$downloadedReposFolder = "C:\TempMigration"

# Set TFS PAT as an environment variable for git-tfs
[System.Environment]::SetEnvironmentVariable("GIT_TFS_PAT", $tfsPat, [System.EnvironmentVariableTarget]::User)

# Disable SSL verification globally for Git (if necessary)
git config --global http.sslVerify false

# Create the downloadedtfvcrepos directory if it doesn't exist
if (-not (Test-Path -Path $downloadedReposFolder)) {
    New-Item -ItemType Directory -Force -Path $downloadedReposFolder
}

foreach ($proj in $projectData) {
    if ($null -eq $proj -or $null -eq $proj.ProjectName) {
        Write-Host "Skipping invalid project entry: $proj" >> conversionlog.txt
        continue
    }

    $projectName = $proj.ProjectName.Trim()
    $encodedProjectName = $projectName -replace ' ', '%20'

    Write-Host "`nProcessing project: $projectName" >> conversionlog.txt

    foreach ($repo in $proj.Repositories) {
        if ($repo.RepositoryType -ne "TFVC") {
            Write-Host "Skipping non-TFVC repository: $($repo.RepositoryName)" >> conversionlog.txt
            continue
        }

        $tfvcPath = $repo.RepositoryName
        $repoNameRaw = ($tfvcPath -split '/')[-1] -replace '[^\w\-]', '-'
        $repoPath = Join-Path -Path $downloadedReposFolder -ChildPath $repoNameRaw

        # Attempt GitHub repo creation first
        $createRepoUrl = "https://api.github.com/orgs/$destinationorganization/repos"
        $repoBody = @{
            name        = $repoNameRaw
            visibility  = "internal"
            description = "Migrated from TFS TFVC: $tfvcPath"
        } | ConvertTo-Json -Depth 3

        $headers = @{
            Authorization  = "token $githubPat"
            "User-Agent"   = "TFS-to-GitHub-Migration-Script"
            Accept         = "application/vnd.github+json"
            "Content-Type" = "application/json"
        }

        Write-Host "`n➡️ Creating GitHub repo: $repoNameRaw" | Tee-Object -Append -FilePath conversionlog.txt
        Write-Host "POST $createRepoUrl" | Tee-Object -Append -FilePath conversionlog.txt
        Write-Host "Request Body: $repoBody" | Tee-Object -Append -FilePath conversionlog.txt

        try {
            $response = Invoke-RestMethod -Uri $createRepoUrl -Method Post -Headers $headers -Body $repoBody -ErrorAction Stop
            Write-Host "✅ GitHub repo created successfully: $repoNameRaw" | Tee-Object -Append -FilePath conversionlog.txt
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.Value__
            $errorStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorStream)
            $responseBody = $reader.ReadToEnd()

            Write-Host "❌ Failed to create GitHub repo: $repoNameRaw" | Tee-Object -Append -FilePath conversionlog.txt
            Write-Host "Status Code: $statusCode" | Tee-Object -Append -FilePath conversionlog.txt
            Write-Host "Error Response: $responseBody" | Tee-Object -Append -FilePath conversionlog.txt
            continue
        }

        # Clean the directory if it exists
        if (Test-Path -Path $repoPath) {
            Remove-Item -Recurse -Force $repoPath
        }

        # Ensure the directory exists before cloning
        if (-not (Test-Path -Path $repoPath)) {
            Write-Host "Directory $repoPath does not exist. Creating it..." | Tee-Object -Append -FilePath conversionlog.txt
            New-Item -ItemType Directory -Force -Path $repoPath | Out-Null
        }

        Write-Host "Cloning TFVC repository: $tfvcPath to $repoPath" >> conversionlog.txt

        # Execute the git-tfs clone command with --workspace
        $gitTfsCloneCommand = "git tfs clone $organization $tfvcPath --workspace=$repoPath --branches=auto --username=PersonalAccessToken --password=$tfsPat --no-ssl-verify"
        Write-Host "Executing: $gitTfsCloneCommand" | Tee-Object -Append -FilePath conversionlog.txt
        Start-Process -NoNewWindow -FilePath "cmd.exe" -ArgumentList "/c $gitTfsCloneCommand" -Wait

        # Check if the cloning was successful
        if (-not (Test-Path -Path (Join-Path -Path $repoPath -ChildPath ".git"))) {
            Write-Host "❌ Failed to clone repository: $tfvcPath. Directory $repoPath is not a valid Git repository." | Tee-Object -Append -FilePath conversionlog.txt
            continue
        }

        cd $repoPath

        if (git remote | Select-String -Pattern "origin") {
            git remote remove origin
        }

        $remoteUrl = "https://$($githubPat)@github.com/$($destinationorganization)/$($repoNameRaw).git"
        Write-Host "Adding origin with URL: $remoteUrl" >> conversionlog.txt
        git remote add origin $remoteUrl

        Write-Host "Pushing all branches to origin..." >> conversionlog.txt
        git push -u origin --all
        git push origin --tags

        git tfs cleanup
        cd ..
    }
}

Write-Host "✅ Complete downloading and migrating repos" >> conversionlog.txt
