# ===== CONFIGURATION =====
$tfsUrl = "http://cvwiisxd20878.silver.com/DefaultCollection/"  # Update if needed
$outputCsv = "$env:USERPROFILE\Documents\TFS_Users_Report.csv"  # Save to Documents folder

# ===== LOAD TFS CLIENT ASSEMBLIES =====
try {
    # Specify the path to the TFS client libraries if needed
    $tfsLibPath = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\TestTools\TeamExplorerClient"  # Update this path if assemblies are downloaded manually
    # Load assemblies
    Add-Type -Path "$tfsLibPath\Microsoft.TeamFoundation.Client.dll"
    Add-Type -Path "$tfsLibPath\Microsoft.TeamFoundation.Common.dll"
} catch {
    Write-Host "❌ Failed to load TFS assemblies. Ensure Visual Studio Team Explorer or TFS SDK is installed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ===== CONNECT TO TFS =====
try {
    # Prompt for credentials
    $credentials = Get-Credential -Message "Enter your TFS credentials"
    $tfsCollection = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsUrl, $credentials)
    $tfsCollection.EnsureAuthenticated()
    Write-Host "✅ Connected to TFS: $tfsUrl" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to connect to TFS. Check the URL and authentication." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ===== GET IDENTITY MANAGEMENT SERVICE =====
try {
    $identityService = $tfsCollection.GetService([Microsoft.TeamFoundation.Server.IIdentityManagementService])
    if (-not $identityService) {
        throw "Identity Management Service is unavailable."
    }
    Write-Host "✅ Retrieved Identity Management Service." -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to retrieve Identity Management Service. Attempting fallback..." -ForegroundColor Yellow
    try {
        # Fallback to IdentityService
        $identityService = $tfsCollection.GetService([Microsoft.TeamFoundation.Framework.Client.IdentityService])
        if (-not $identityService) {
            throw "Fallback Identity Service is also unavailable."
        }
        Write-Host "✅ Retrieved Identity Service (fallback)." -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to retrieve any Identity Service." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
}

# ===== GET ALL APPLICATION GROUPS =====
try {
    $groups = $identityService.ListApplicationGroups("", [Microsoft.TeamFoundation.Framework.Common.ReadIdentityOptions]::None)
    Write-Host "✅ Retrieved application groups." -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to retrieve application groups." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ===== PROCESS GROUPS AND MEMBERS =====
$results = @()

foreach ($group in $groups) {
    try {
        # Expand group to get members
        $expandedGroup = $identityService.ReadIdentity(
            [Microsoft.TeamFoundation.Framework.Common.IdentitySearchFactor]::Identifier,
            $group.Descriptor.Identifier,
            [Microsoft.TeamFoundation.Framework.Common.ReadIdentityOptions]::ExpandMembership
        )
    } catch {
        Write-Host "❌ Failed to expand group: $($group.DisplayName)" -ForegroundColor Yellow
        continue
    }

    foreach ($member in $expandedGroup.Members) {
        try {
            $memberIdentity = $identityService.ReadIdentity(
                [Microsoft.TeamFoundation.Framework.Common.IdentitySearchFactor]::Identifier,
                $member,
                [Microsoft.TeamFoundation.Framework.Common.ReadIdentityOptions]::None
            )

            # Add null checks for member properties
            $results += [PSCustomObject]@{
                GroupName    = $group.DisplayName
                DisplayName  = if ($memberIdentity.DisplayName) { $memberIdentity.DisplayName } else { "N/A" }
                AccountName  = if ($memberIdentity.UniqueName) { $memberIdentity.UniqueName } else { "N/A" }
                EmailAddress = if ($memberIdentity.MailAddress) { $memberIdentity.MailAddress } else { "N/A" }
            }
        } catch {
            Write-Host "❌ Failed to retrieve member details for group: $($group.DisplayName)" -ForegroundColor Yellow
            continue
        }
    }
}

# ===== EXPORT TO CSV =====
try {
    $results | Sort-Object GroupName, DisplayName | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
    Write-Host "✅ User export complete. File saved at: $outputCsv" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to export results to CSV. Check file path and permissions." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
