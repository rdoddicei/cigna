
# Workflow Documentation: TFS Git Repository Migration

This document provides a comprehensive overview of the **migrate-tfgit-github.yml** GitHub Actions workflow, along with detailed execution steps and an explanation of the associated PowerShell script (**tfgit-to-github.ps1**). It also includes best practices, potential pitfalls, and troubleshooting tips to ensure a successful migration.

---

## Workflow Name

**TFS Git Repository Migration**

---

## Trigger

The workflow is triggered manually using the **workflow_dispatch** event. It requires the following user inputs:

- **Project Name**: Specifies the TFS project containing the Git repository.
- **Repository Name**: The name of the TFS Git repository you want to migrate.

These inputs ensure flexibility, enabling you to migrate different repositories as needed.

---

## Job: migrate-tfgit

This job runs on a **self-hosted runner** configured for migration tasks. It involves the following steps:

### 🔧 Steps

1️⃣ **Disable SSL Verification**  
Disables SSL verification for Git to avoid issues with self-signed certificates or outdated SSL configurations in legacy TFS environments.

2️⃣ **Checkout Code**  
Uses **actions/checkout@v4** to pull the latest version of the workflow and migration scripts, ensuring that the migration logic is always up to date.

3️⃣ **Set Up Environment Variables**  
Fetches **TFS_PAT** and **GITHUB_PAT** from GitHub Secrets for secure authentication.  
These tokens are essential for accessing the TFS and GitHub APIs.

4️⃣ **Generate Input JSON File**  
Runs a PowerShell step to dynamically create an `input.json` file containing the project and repository details.  
This file acts as the single source of truth for the migration script.

5️⃣ **Execute Migration PowerShell Script**  
Invokes the **tfgit-to-github.ps1** PowerShell script, passing the input JSON file, TFS URL, and GitHub organization as parameters.

---

## Execution Steps

To initiate a migration:

1️⃣ Go to the **Actions** tab in your GitHub repository.  
2️⃣ Select the **TFS Git Repository Migration** workflow.  
3️⃣ Click **Run workflow**.  
4️⃣ Provide the **Project Name** and **Repository Name** inputs.  
5️⃣ Click **Run workflow** to start the migration.

The workflow will:

✅ Generate the input JSON file  
✅ Invoke the migration script  
✅ Log progress and errors for your review

---

## PowerShell Script: tfgit-to-github.ps1

The **tfgit-to-github.ps1** script handles the actual migration of the Git repository from TFS to GitHub.

### ✏️ Key Functions

- **Input Parsing**  
  Reads `input.json` to extract migration details, ensuring accurate repository targeting.

- **Authentication**  
  Uses environment variables (`TFS_PAT` and `GITHUB_PAT`) to authenticate with both TFS and GitHub.

- **Repository Cloning and Migration**  
  - Uses `git clone --mirror` (or similar) to create a full copy of the repository, including all branches, tags, and history.  
  - Pushes the repository to the target GitHub repository, ensuring a complete migration.

- **Error Handling and Logging**  
  - Logs all migration steps to help with troubleshooting.  
  - Implements error handling to catch and report any issues during the migration.

---

## 🚀 Manual Execution

If needed (e.g., for testing or debugging), you can run the script manually:

\`\`\`powershell
./repo-migration/tfgit-to-github.ps1 -JsonFilePath "./repo-migration/input.json" -TfsUrl "https://tfs.server.url" -GitHubOrg "github-org-name"
\`\`\`

---

## Migrating a TFS Git Repository to GitHub

When migrating a TFS Git repository from a TFS server to GitHub, follow these steps to ensure a smooth and successful migration:

✅ **Select the correct project and repository:**  
- In the **Select the TFS Project** dropdown, choose the name of the TFS project you want to migrate.  
- In the **Select the Repository** dropdown, choose the specific repository (or source branch) you want to migrate.

✅ **Trigger the workflow:**  
- After selecting the project and repository, click **Run workflow** to start the migration process.  
- The workflow will use your provided selections to prepare the environment and execute the migration script automatically.

---

**TFS Git Project in TFS (Before Migration):**  
*(insert screenshot here)*

**After Migration:**  
*(insert screenshot here)*

**Note:**  
The new GitHub repository will be created with the following naming convention:  
**TFS project name** followed by the **repository name**.  
This ensures that the migrated repository in GitHub maintains a clear link to its TFS source.

---

## Validation After Migration

🔍 After the migration completes, validate the following:

- **Commit History:**  
  Ensure all commits, branches, and tags have been migrated correctly and that the history in GitHub matches the original TFS repository.

- **File Structure:**  
  Confirm that the directory structure, including folders and files, is consistent in the new GitHub repository.

- **Metadata:**  
  Check that commit messages, authorship information, and timestamps are intact.

- **Permissions:**  
  Review repository permissions and branch protection rules in GitHub to ensure they align with your team’s security policies.

- **Pull Requests (if applicable):**  
  If using a TFVC to Git migration (rather than TFVC direct), confirm that pull requests are either migrated or archived in the source system for reference.

## Incase of migration failure due to buffer size

- **Migration Failure detection:**
  If the migration is failed with the error as **error: unable to rewind rpc post data: try increasing the buffer size more than 500MB** please follow the steps below

- Start by raising the postBuffer size by logging into the actions runner machine and execute the script


  **git config --global http.postBuffer 524288000**




  ## Usefull links
  **Enable the long path behavior**
  https://github.com/Azure/azure-powershell/wiki/Enable-the-long-path-behavior
  
  **Migration Failure due to buffer size - Quick Fix**
  https://stackoverflow.com/questions/6842687/the-remote-end-hung-up-unexpectedly-while-git-cloning

