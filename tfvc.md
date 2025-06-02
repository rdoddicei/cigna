
# Workflow Documentation: TFVC Repository Migration

This document provides a comprehensive overview of the **migration-tfs-github.yml** GitHub Actions workflow, along with detailed execution steps and an explanation of the associated PowerShell script (**tfvc-to-github.ps1**).

---

## Workflow Name: TFVC Repository migration with User Input

## Trigger

The workflow is triggered manually using the **workflow_dispatch** event. It takes user inputs for:
- **Project Name**: Select the TFS project.
- **Repository Name**: Select the TFVC repository within that project.

## Job: migrate-tfvc

This job runs on a self-hosted runner group called **TFS-Migration-Runner** and consists of the following steps:

### 🔧 Steps

1️⃣ **Disable SSL Verification**  
Disables Git SSL verification globally to bypass any SSL-related issues during migration.(not recommanded the proper SSL needs to be updated in the runner so that we can repove this step)

2️⃣ **Checkout Code**  
Uses the **actions/checkout@v4** action to pull the workflow and migration scripts.

3️⃣ **Set Up Environment Variables**  
- Loads TFS and GitHub PATs from GitHub Secrets.
- Sets them as environment variables for the migration process.

4️⃣ **Generate Input JSON File**  
- Uses PowerShell to create a JSON file (`input.json`) containing the selected project and repository.
- This file is used by the migration script to identify which repository to migrate.

5️⃣ **Execute Migration Script**  
- Runs the **tfvc-to-github.ps1** PowerShell script.
- Passes the JSON file path, TFS URL, and GitHub organization as parameters.

---

## Execution Steps

To run this workflow:

1️⃣ Navigate to the **Actions** tab in your GitHub repository.  
2️⃣ Select the **TFVC Repository migration with User Input** workflow.  
3️⃣ Click on **Run workflow**.  
4️⃣ Choose the desired **Project Name** and **Repository Name** from the dropdowns.  
5️⃣ Click **Run workflow** to trigger the migration.

The workflow will execute the defined steps, creating a JSON input file and invoking the PowerShell script to complete the migration.

---

## PowerShell Script: tfvc-to-github.ps1

This PowerShell script (`tfvc-to-github.ps1`) is responsible for performing the actual migration from TFS to GitHub. Here’s an explanation of its main components:

### ✏️ Key Functions

- **Input Parsing**:  
  The script reads the `input.json` file to get the **Project Name** and **Repository Name** for migration.

- **Authentication**:  
  Uses the environment variables (`TFS_PAT` and `GITHUB_PAT`) to authenticate with TFS and GitHub.

- **Migration Execution**:  
  The script typically runs commands like `git-tfs clone` or similar migration tools to perform the migration.  
  It ensures the TFVC repository history is cloned and pushed to the target GitHub repository.

- **Error Handling**:  
  Includes checks for migration status, logs any errors, and provides output to track progress.

### 🚀 How to Use

This script is automatically executed by the GitHub Actions workflow. However, you can also run it manually (for testing or debugging) using PowerShell:

```powershell
./repo-migration/tfvc-to-github.ps1 -JsonFilePath "./repo-migration/input.json" -TfsUrl "https://tfs.server.url" -GitHubOrg "github-org-name"
```

Replace the parameters as needed for your environment.

---

**Summary**: This documentation provides a complete guide to the TFVC to GitHub migration workflow, including step-by-step execution instructions and a high-level explanation of the PowerShell script used for migration.

