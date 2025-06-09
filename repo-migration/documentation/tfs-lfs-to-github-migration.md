
# Migrating TFS 2017 Server LFS Repositories to GitHub

This guide provides a clear step-by-step process to migrate large repositories (with Git LFS) from **TFS 2017 Server** to **GitHub**.

---

## 🚀 Steps to Migrate TFS 2017 Server LFS Repositories to GitHub

### 1️⃣ Pre-Migration Preparation

✅ **Understand your repo type**:
- TFS 2017 supports both TFVC and Git repos.
- This guide assumes TFS Git Repos using Git LFS.

✅ **Inventory your repos**:
- List all Git repos you want to migrate.
- Identify which ones use Git LFS (`.gitattributes` file will have LFS tracked paths).

✅ **Check Git LFS usage**:

```bash
git lfs ls-files
```

✅ **Install Git and Git LFS** on your migration machine:

- [Download Git](https://git-scm.com/downloads)
- [Download Git LFS](https://git-lfs.com)

Then initialize Git LFS:

```bash
git lfs install
```

---

### 2️⃣ Clone Repo from TFS with LFS

✅ Use the **TFS Git Repo URL**:

```bash
git clone --mirror https://tfs.example.com/tfs/DefaultCollection/Project/_git/RepoName
cd RepoName.git
```

✅ LFS will also clone LFS pointers.

---

### 3️⃣ Create GitHub Repository

✅ Go to your GitHub Organization → Create New Repository (empty repo, no README yet).

✅ Get the GitHub Repo URL.

---

### 4️⃣ Push to GitHub with LFS

✅ Ensure LFS is enabled on the target repo:

```bash
git lfs install
git lfs track "*.psd" "*.zip"
```

✅ Push the mirror clone:

```bash
git remote set-url origin https://github.com/org/repo.git
git push --mirror
```

✅ If needed, force-push LFS files:

```bash
git lfs push --all origin
```

---

### 5️⃣ Post-Migration Validation

✅ Validate the GitHub repo:
- All branches and tags are present.
- LFS files are showing correctly:

```bash
git lfs ls-files
```

✅ Validate your `.gitattributes` was migrated.

✅ Run a clone from GitHub and verify LFS files download properly:

```bash
git clone https://github.com/org/repo.git
git lfs pull
```

---

### 6️⃣ Optional: Clean Up and Migrate Build Pipelines

✅ Migrate any build pipelines from TFS Build → GitHub Actions or other CI/CD.

✅ Reference: [Azure Pipelines Migration Guide](https://learn.microsoft.com/en-us/azure/devops/pipelines/migrate/overview)

---

## 📚 Documentation URLs

- [GitHub Docs - About Git LFS](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage)
- [Git LFS Official Site](https://git-lfs.com)
- [GitHub Docs - Migrating repositories to GitHub](https://docs.github.com/en/get-started/importing-your-projects-to-github/importing-source-code-to-github/about-migrations-to-github)
- [GitHub Docs - Using Git LFS](https://docs.github.com/en/repositories/working-with-files/managing-large-files/versioning-large-files)
- [Microsoft - Migrate from TFS](https://learn.microsoft.com/en-us/azure/devops/migrate/migration-overview?view=azure-devops)

---
