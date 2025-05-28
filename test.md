
# Documentation: Migration Workflow for TFVC to GitHub

This document provides a detailed explanation of the `migration-tfs-github.yml` workflow, its integration with the PowerShell scripts, and the JSON file used in the migration process.

## Workflow Overview

The `migration-tfs-github.yml` file defines a GitHub Actions workflow to migrate repositories from TFVC (Team Foundation Version Control) to GitHub. It uses PowerShell scripts to automate the migration process.

### Workflow Name

**Migrate TFVC to GitHub**

### Trigger

The workflow is triggered manually using the `workflow_dispatch` event.

### Job: migrate-tfvc

This job performs the migration process. It runs on a self-hosted runner group named `TFS-Migration-Runner`.

#### Steps

1️⃣ **Disable SSL Verification**

Disables SSL verification globally for Git to avoid certificate issues during the migration process.

```bash
git config --global http.sslVerify false
```

2️⃣ **Checkout Code**

Uses the `actions/checkout@v4` action to clone the repository containing the workflow and scripts.

3️⃣ **Set Up Environment Variables**

Sets up environment variables for the TFS and GitHub Personal Access Tokens (PATs). These tokens are stored as GitHub secrets (`TFS_PAT` and `GH_PAT`) and are required for authentication.

```yaml
env:
  TFS_PAT: "{{ secrets.TFS_PAT }}"
  GITHUB_PAT: "{{ secrets.GH_PAT }}"
```

```powershell
[System.Environment]::SetEnvironmentVariable("GIT_TFS_PAT", $env:TFS_PAT, [System.EnvironmentVariableTarget]::User)
```

4️⃣ **Run Migration PowerShell Script**

Executes the `tfvc-to-github.ps1` PowerShell script to perform the migration. The script is passed three parameters:

- `-TfsUrl`: The URL of the TFS server.
- `-GitHubOrg`: The target GitHub organization.
- `-JsonFilePath`: The path to the JSON file containing project and repository details.

```powershell
./repo-migration/tfvc-to-github.ps1 -TfsUrl "https://tfs.sys.cigna.com/tfs/DefaultCollection" -GitHubOrg "cigna-group-infrastructure-services" `
-JsonFilePath "./repo-migration/projectRepoDetailsTFS2017.json"
```

## PowerShell Script: tfvc-to-github.ps1

The `tfvc-to-github.ps1` script is the core of the migration process. It performs the following steps:

### Parameters

- **TfsUrl**: The URL of the TFS server.
- **GitHubOrg**: The target GitHub organization.
- **JsonFilePath**: The path to the JSON file containing project and repository details.

### Workflow

1. **Read Tokens and Setup**: Reads the TFS and GitHub tokens (hardcoded in the script or passed via environment variables). Creates a working directory for cloning repositories.
2. **Read JSON Input**: Reads the JSON file specified by the `JsonFilePath` parameter. This file contains details of the projects and repositories to be migrated.
3. **Process Each Project and Repository**: Iterates through each project and its repositories in the JSON file. For each repository:
   - **Create GitHub Repository**: Uses the GitHub API to create a new repository in the specified organization.
   - **Clone TFVC Repository**: Uses `git-tfs` to clone the TFVC repository to a local directory.
   - **Push to GitHub**: Pushes the cloned repository to the newly created GitHub repository.
   - **Cleanup**: Deletes the local clone after the migration is complete.

## JSON File: projectRepoDetailsTFS2017.json

This JSON file contains the details of the projects and repositories to be migrated. It is used as input by the `tfvc-to-github.ps1` script.

### Structure

```json
[
  {
    "ProjectName": "CCP-GDD_OTIR_WEB",
    "Repositories": [
      {
        "RepositoryName": "$/CCP-GDD_OTIR_WEB",
        "RepositoryType": "TFVC"
      }
    ]
  }
]
```

### Fields

- **ProjectName**: The name of the TFS project.
- **Repositories**: An array of repositories within the project.
  - **RepositoryName**: The name of the repository in TFS.
  - **RepositoryType**: The type of repository (TFVC or Git).

## Flow Diagram

```plaintext
Workflow Triggered (workflow_dispatch)
  |
  v
GitHub Actions Workflow (migration-tfs-github.yml)
  |
  v
PowerShell Script Execution (tfvc-to-github.ps1)
  |
  v
JSON File Read (projectRepoDetailsTFS2017.json)
  |
  v
Process Each Project and Repository:
  - Create GitHub Repository
  - Clone TFVC Repository
  - Push to GitHub
  - Cleanup
  |
  v
Migration Complete
```

## Integration Between Files

- **migration-tfs-github.yml**: Triggers the migration process and sets up the environment for the PowerShell script.
- **tfvc-to-github.ps1**: Reads the JSON file and performs the actual migration tasks (creating GitHub repositories, cloning TFVC repositories, and pushing to GitHub).
- **projectRepoDetailsTFS2017.json**: Provides the list of projects and repositories to be migrated.

## Key Notes

✅ **Authentication**: Ensure that the TFS and GitHub PATs are correctly configured as GitHub secrets (`TFS_PAT` and `GH_PAT`).  
✅ **Dependencies**: The `git-tfs` tool must be installed on the runner for cloning TFVC repositories.  
✅ **Error Handling**: The PowerShell script includes error handling for failed API calls and repository operations.  
✅ **Cleanup**: Local clones of repositories are deleted after migration to save disk space.

---

This documentation provides a comprehensive understanding of the workflow, its components, and how they interact to perform the migration from TFVC to GitHub.
