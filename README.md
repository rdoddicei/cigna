# tfs-migration 
This repository contains scripts that are require to migrate TFS to GitHub


listprojects.ps1 - lists out the projects in the organization/collection outputs them to json file.
* this will call Findbuilddefinitions.ps1 - which reads/accepts json of the project lists form the previous script and finds the build and release definitions for the projects.  It creates a masterjson file output.


Everything from here forward requires a json file with the project/repo and build definition 
Note: if no new projects/ repositories/ build definitions are created then the above scripts do not need re-run.  However, if this process takes a while re-running may be necesary.  