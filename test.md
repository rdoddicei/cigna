# Workflow Documentation: TFVC Repository Migration

This document provides a comprehensive overview of the **migration-tfs-github.yml** GitHub Actions workflow, along with detailed execution steps and an explanation of the associated PowerShell script (**tfvc-to-github.ps1**).

---

## Workflow Name

**TFVC Repository Migration**

## Trigger

The workflow is triggered manually using the **workflow_dispatch** event. It takes user inputs for:
- **Project Name**: Specifies the TFS project containing the TFVC repository.
- **Repository Name**: Specifies the TFVC repository to be migrated.

## Job: migrate-tfvc

This job runs on a self-hosted runner group called **TFS-Migration-Runner** and consists of the following steps:

### 🔧 Steps

1️⃣ **Disable SSL Verification**  
Disables Git SSL verification globally to avoid SSL-related issues during migration.

2️⃣ **Checkout Code**  
Uses the **actions/checkout@v4** action to pull the workflow and migration scripts from the repository.

3️⃣ **Set Up Environment Variables**  
- Loads TFS and GitHub Personal Access Tokens (PATs) from GitHub Secrets.
- Sets them as environment variables (`TFS_PAT` and `GITHUB_PAT`) for the migration process.

4️⃣ **Generate Input JSON File**  
- Uses PowerShell to create an `input.json` file containing the selected project and repository.
- This file serves as the input for the migration script.

5️⃣ **Execute Migration PowerShell Script**  
- Runs the **tfvc-to-github.ps1** PowerShell script.
- Passes the JSON file path, TFS URL, and GitHub organization as parameters to the script.

---

## Execution Steps

To run this workflow:

1️⃣ Go to the **Actions** tab in your GitHub repository.  
2️⃣ Select the **TFVC Repository Migration** workflow.  
3️⃣ Click on **Run workflow**.  
4️⃣ Choose the desired **Project Name** and **Repository Name** from the dropdowns.  
5️⃣ Click **Run workflow** to trigger the migration.

The workflow will generate an input JSON file and invoke the PowerShell script to migrate the repository from TFS to GitHub.

---

## PowerShell Script: tfvc-to-github.ps1

The **tfvc-to-github.ps1** script is responsible for the actual migration of the repository. Here’s a breakdown of its main components:

### ✏️ Key Functions

- **Input Parsing**:  
  Reads the `input.json` file to get the **Project Name** and **Repository Name** for migration.

- **Authentication**:  
  Uses environment variables (`TFS_PAT` and `GITHUB_PAT`) to authenticate with TFS and GitHub.

- **TFVC to Git Conversion**:  
  Runs commands like `git-tfs clone` to fetch the repository history from TFS, then pushes the history to the target GitHub repository.

- **Logging and Error Handling**:  
  Provides logs for progress and handles errors gracefully, ensuring traceability of the migration process.

### 🚀 Manual Execution

While the script is run automatically by the GitHub Actions workflow, you can also execute it manually (e.g., for testing) using the following PowerShell command:

```powershell
./repo-migration/tfvc-to-github.ps1 -JsonFilePath "./repo-migration/input.json" -TfsUrl "https://tfs.server.url" -GitHubOrg "github-org-name"
