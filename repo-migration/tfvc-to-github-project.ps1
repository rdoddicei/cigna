# TFS and GitHub Personal Access Tokens
$tfsPat = "***********" # Replace with your TFS PAT
$githubPat = "***********" # Replace with your GitHub PAT

# Encode the TFS PAT for the Authorization header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("user:$tfsPat"))

# Configuration
$organization = "https://tfs.sys.cigna.com/tfs/DefaultCollection"
$destinationOrganization = "cigna-group"
$projectListJsonPath = "C:\Users\C9F9HC\Migration\cigna-tfs-to-github\projectRepoDetailsTFS2017.json" # Path to the JSON file containing project and repository details
$downloadedReposFolder = "C:\TFSMigration" # Path to the folder where TFVC repositories will be downloaded

# Read and parse the JSON file
if (-not (Test-Path -Path $projectListJsonPath)) {
    Write-Host "Error: JSON file not found at $projectListJsonPath" -ForegroundColor Red
    exit 1
}

$projectData = Get-Content -Raw $projectListJsonPath | ConvertFrom-Json

# Set TFS PAT as an environment variable for git-tfs
[System.Environment]::SetEnvironmentVariable("GIT_TFS_PAT", $tfsPat, [System.EnvironmentVariableTarget]::User)

# Create the downloaded repos directory if it doesn't exist
if (-not (Test-Path -Path $downloadedReposFolder)) {
    New-Item -ItemType Directory -Force -Path $downloadedReposFolder
}

foreach ($proj in $projectData) {
    if ($null -eq $proj -or $null -eq $proj.ProjectName) {
        Write-Host "Skipping invalid project entry: $proj"
        continue
    }

    $projectName = $proj.ProjectName.Trim()
    Write-Host "`nProcessing project: $projectName"

    foreach ($repo in $proj.Repositories) {
        if ($repo.RepositoryType -ne "TFVC") {
            Write-Host "Skipping non-TFVC repository: $($repo.RepositoryName)"
            continue
        }

        $tfvcPath = $repo.RepositoryName
        $repoNameRaw = ($tfvcPath -split '/')[-1] -replace '[^\w\-]', '-'
        $repoPath = Join-Path -Path $downloadedReposFolder -ChildPath $repoNameRaw

        # Attempt GitHub repo creation
        $createRepoUrl = "https://api.github.com/orgs/$destinationOrganization/repos"
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

        try {
            Invoke-RestMethod -Uri $createRepoUrl -Method Post -Headers $headers -Body $repoBody -ErrorAction Stop
            Write-Host "✅ GitHub repo created successfully: $repoNameRaw"
        } catch {
            Write-Host "❌ Failed to create GitHub repo: $repoNameRaw. Skipping."
            continue
        }

        # Clean the directory if it exists
        if (Test-Path -Path $repoPath) {
            Remove-Item -Recurse -Force $repoPath
        }

        # Clone the TFVC repository
        Write-Host "Cloning TFVC repository: $tfvcPath to $repoPath"
        $gitTfsCloneCommand = "git tfs clone $organization $tfvcPath $repoPath --branches=auto --username=PersonalAccessToken --password=$tfsPat"
        Start-Process -NoNewWindow -FilePath "cmd.exe" -ArgumentList "/c $gitTfsCloneCommand" -Wait

        if (-not (Test-Path -Path $repoPath)) {
            Write-Host "❌ Failed to clone repository: $tfvcPath. Directory $repoPath does not exist."
            continue
        }

        # Push to GitHub
        cd $repoPath

        if (git remote | Select-String -Pattern "origin") {
            git remote remove origin
        }

        $remoteUrl = "https://$githubPat@github.com/$destinationOrganization/$repoNameRaw.git"
        Write-Host "Adding origin with URL: $remoteUrl"
        git remote add origin $remoteUrl

        Write-Host "Pushing all branches to origin..."
        git push -u origin --all
        git push origin --tags

        git tfs cleanup
        cd ..
    }
}

Write-Host "✅ Migration completed successfully."
