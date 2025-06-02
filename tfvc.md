
# Migrating TFGIT Repository to GitHub

When migrating a TFGIT repository from a TFS server to GitHub, follow these steps to ensure a smooth and successful migration:

✅ **Select the correct project and repository:**

- In the **Select the TFS Project** dropdown, choose the name of the TFS project you want to migrate.
- In the **Select the Repository** dropdown, choose the specific repository (or source branch) you want to migrate.

✅ **Trigger the workflow:**

- After selecting the project and repository, click on **Run workflow** to start the migration process.
- The workflow will use your provided selections to prepare the environment and execute the migration script automatically.

---

**TFGIT Project in TFS (Before Migration):**  
*(insert screenshot here)*

**After Migration:**  
*(insert screenshot here)*

**Note:**  
The new GitHub repository will be created with the following naming convention:  
**TFS project name** followed by the **repository name**.  
This ensures that the migrated repository in GitHub maintains a clear link to its TFS source.

---

## Validation After Migration

🔍 After the migration completes, it's crucial to validate the following:

- **Commit History:**  
  Check that all commits, branches, and tags have been migrated correctly and that the history in GitHub matches the original TFS repository.

- **File Structure:**  
  Ensure that the directory structure, including folders and files, is consistent in the new GitHub repository.

- **Metadata:**  
  Validate that metadata such as commit messages, authorship information, and timestamps are intact.

- **Permissions:**  
  Review repository permissions and branch protection rules in GitHub to ensure they align with your team’s security policies.

- **Pull Requests (if applicable):**  
  If using a TFVC to Git migration (not TFVC direct), confirm that pull requests are either migrated or archived in the source system for reference.
