# Required tokens
$tfsPat = "*******" # Replace with your TFS PAT
$githubPat = "*************" # Replace with your GitHub PAT

# Settings
$organization = "https://tfs.sys.cigna.com/tfs/DefaultCollection"
$destinationorganization = "cigna-group"
$ProjectListJsonPath = "C:\Users\C9F9HC\Migration\cigna-tfs-to-github\projectRepoDetailsTFS2017.json" # Update the PATH
$logPath = "C:\Users\C9F9HC\Migration\cigna-tfs-to-github\conversionlog.txt" # Path to log file
$downloadedReposFolder = "C:\git-repos"

# Ensure repo folder exists
if (-not (Test-Path -Path $downloadedReposFolder)) {
    New-Item -ItemType Directory -Path $downloadedReposFolder | Out-Null
}

# Validate JSON file
if (-not (Test-Path $ProjectListJsonPath)) {
    Write-Host "JSON file not found at: $ProjectListJsonPath" -ForegroundColor Red
    exit 1
}

# Load JSON
$projectData = Get-Content -Raw $ProjectListJsonPath | ConvertFrom-Json

# Process each project
foreach ($proj in $projectData) {
    if (-not $proj.ProjectName) {
        Write-Host "Skipping invalid project entry." | Tee-Object -Append -FilePath $logPath
        continue
    }

    $projectName = $proj.ProjectName.Trim()
    Write-Host "Processing project: $projectName" | Tee-Object -Append -FilePath $logPath

    foreach ($repo in $proj.Repositories) {
        if ($repo.RepositoryType -ne "Git") {
            Write-Host "Skipping non-Git repository: $($repo.RepositoryName)" | Tee-Object -Append -FilePath $logPath
            continue
        }

        $gitRepoUrl = $repo.RepositoryUrl
        if (-not $gitRepoUrl) {
            $gitRepoUrl = "$organization/$projectName/_git/$($repo.RepositoryName)"
        }

        $repoName = ($gitRepoUrl -split '/')[-1].ToLower() -replace '[^\w\-]', '-'
        $repoPath = Join-Path $downloadedReposFolder $repoName

        # GitHub API call
        $createRepoUrl = "https://api.github.com/orgs/$destinationorganization/repos"
        $repoBody = @{
            name        = $repoName
            visibility  = "internal"
            description = "Migrated from TFS Git: $gitRepoUrl"
        } | ConvertTo-Json -Depth 3

        $headers = @{
            Authorization  = "token $githubPat"
            "User-Agent"   = "MigrationScript"
            Accept         = "application/vnd.github+json"
        }

        try {
            Write-Host "Creating GitHub repo: $repoName" | Tee-Object -Append -FilePath $logPath
            Invoke-RestMethod -Uri $createRepoUrl -Method Post -Headers $headers -Body $repoBody
        } catch {
            Write-Host "Failed to create GitHub repo: $repoName" | Tee-Object -Append -FilePath $logPath
            continue
        }

        # Clone from TFS using PAT
        $encodedTfsUrl = $gitRepoUrl -replace "^https://", "https://$tfsPat@"
        $maskedTfsUrl = $encodedTfsUrl -replace $tfsPat, '***'
        Write-Host "Cloning from TFS URL: $maskedTfsUrl" | Tee-Object -Append -FilePath $logPath

        git -c http.sslVerify=true clone --mirror $encodedTfsUrl $repoPath

        if (-not (Test-Path $repoPath)) {
            Write-Host "Clone failed: $repoName" | Tee-Object -Append -FilePath $logPath
            continue
        }

        # Push to GitHub
        Set-Location $repoPath
        git remote set-url origin "https://$githubPat@github.com/$destinationorganization/$repoName.git"
        git push --mirror
        Set-Location $downloadedReposFolder
    }
}

Write-Host "Migration complete." | Tee-Object -Append -FilePath $logPath
