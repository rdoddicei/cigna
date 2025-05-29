param(
    [Parameter(Mandatory = $true)] [string]$TfsUrl,
    [Parameter(Mandatory = $true)] [string]$GitHubOrg,
    [Parameter(Mandatory = $true)] [string]$JsonFilePath
)

# Set tokens
$TfsToken = "---"      # If needed for TFS authentication
$GitHubToken = "---"   # GitHub PAT with repo scope

if (-not $TfsToken) { throw "Missing TFS_TOKEN in script." }
if (-not $GitHubToken) { throw "Missing GITHUB_TOKEN in script." }

# Load input JSON
if (-not (Test-Path $JsonFilePath)) {
    throw "JSON input file not found: $JsonFilePath"
}
$jsonContent = Get-Content -Raw -Path $JsonFilePath | ConvertFrom-Json
Write-Output "Loaded $($jsonContent.Count) project(s) from input JSON"

$headers = @{
    Authorization = "token $GitHubToken"
    Accept = "application/vnd.github.v3+json"
    "User-Agent" = "PowerShell-MigrationScript"
}

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

        Write-Output "`nProcessing Repository: $repoName (Type: $repoType)"

        # Create GitHub repository
        $createRepoUri = "https://api.github.com/orgs/$GitHubOrg/repos"
        $repoBody = @{
            name = $repoName
            visibility = "internal"
            auto_init = $false
        } | ConvertTo-Json -Depth 3

        try {
            $response = Invoke-RestMethod -Uri $createRepoUri -Method Post -Headers $headers -Body $repoBody
            Write-Output "GitHub repo created: $($response.full_name)"
        } catch {
            Write-Output "Skipping repo: $repoName - GitHub repo may already exist or failed to create"
            continue
        }

        if ($repoType -eq "GIT") {
            # Prepare Import API URL
            $importUri = "https://api.github.com/repos/$GitHubOrg/$repoName/import"

            # If your TFS requires token in URL for import, insert it here; else leave URL as is.
            $importVcsUrl = $tfsGitUrl
            if ($TfsToken) {
                # Insert token in URL as basic auth (only if TFS supports it)
                $uriParts = [uri]$tfsGitUrl
                $importVcsUrl = "$($uriParts.Scheme)://$($TfsToken)@$($uriParts.Host)$($uriParts.AbsolutePath)"
            }

            $importBody = @{
                vcs = "git"
                vcs_url = $importVcsUrl
                # Optional credentials if needed:
                # vcs_username = "username"
                # vcs_password = "password_or_token"
            } | ConvertTo-Json

            try {
                # Start import
                $startImportResponse = Invoke-RestMethod -Uri $importUri -Method Put -Headers $headers -Body $importBody
                Write-Output "Started import for $repoName"
            } catch {
                Write-Output "Failed to start import for $repoName - $_"
                continue
            }

            # Poll import status up to 80 seconds
            $timeout = 80
            $elapsed = 0
            $pollInterval = 5

            while ($elapsed -lt $timeout) {
                Start-Sleep -Seconds $pollInterval
                $elapsed += $pollInterval

                try {
                    $statusResponse = Invoke-RestMethod -Uri $importUri -Method Get -Headers $headers
                    $importStatus = $statusResponse.status
                    Write-Output "Import status for $repoName: $importStatus"

                    if ($importStatus -eq "complete") {
                        Write-Output "Import completed successfully for $repoName"
                        break
                    }
                    elseif ($importStatus -eq "error") {
                        Write-Output "Import failed for $repoName. Message: $($statusResponse.errors | ConvertTo-Json)"
                        break
                    }
                } catch {
                    Write-Output "Failed to get import status for $repoName - $_"
                    break
                }
            }

            if ($elapsed -ge $timeout) {
                Write-Output "Import timed out after $timeout seconds for $repoName"
            }

        } elseif ($repoType -eq "TFVC") {
            Write-Output "Skipping TFVC repo: $repoName - Not supported by GitHub Import API"
        } else {
            Write-Output "Unknown repo type: $repoType"
        }

        Write-Output "Done: $repoName"
    }

    Write-Output "`nCompleted Project: $projectName"
}

Write-Output "`nAll repositories processed."
