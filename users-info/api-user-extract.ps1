# Input: TFS server URL and PAT
$tfsUrl = "http://cvwiisxd20878.silver.com/DefaultCollection"
$pat = "***********" # Replace with your PAT

# Auth header (Basic with PAT)
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    Accept        = "application/json"
}

# Output array
$allResults = @()

# Step 1: Get list of projects
$projectsUrl = "$tfsUrl/_apis/projects?api-version=6.0"
$projects = Invoke-RestMethod -Uri $projectsUrl -Headers $headers -Method Get

foreach ($project in $projects.value) {
    Write-Host "Processing project: $($project.name)"
    
    # Step 2: Get groups for this project
    $groupsUrl = "$tfsUrl/_apis/graph/groups?scopeDescriptor=Microsoft.TeamFoundation.Identity;$($project.id)&api-version=7.1-preview.1"
    Write-Host "Fetching groups from URL: $groupsUrl"
    try {
        $groups = Invoke-RestMethod -Uri $groupsUrl -Headers $headers -Method Get
        foreach ($group in $groups.value) {
            # Filter for team and Azure DevOps groups
            if ($group.origin -eq "vsts" -or $group.origin -eq "aad") {
                $allResults += [PSCustomObject]@{
                    ProjectName = $project.name
                    GroupName   = $group.displayName
                }
            }
        }
    } catch {
        Write-Warning "Failed to fetch groups for project $($project.name): $($_.Exception.Message)"
    }
}

# Step 3: Export to CSV
$allResults | Export-Csv -Path "TFS_Teams_Groups.csv" -NoTypeInformation
Write-Host "Export complete: TFS_Teams_Groups.csv"
