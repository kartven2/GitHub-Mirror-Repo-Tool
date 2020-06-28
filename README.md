# GitHub-Mirror-Repo-Tool
Automation tool to mirror GitHub repository from different project

-  mirrorRepos.sh: Utility to mirror GitHub repository from different projects.
   Can also be used to sync all the repositories periodically or on need basis.

   This script for instance can be used to mirror all GitHub repositories in
   different GitHub projects/organizations into current
   org (git@github.com:xyz).

   Different source repositories can be specified in an input file.       

   How to use:
   ----------
   1. git@github.com:kartven2/GitHub-Mirror-Repo-Tool.git
   2. cd GitHub-Mirror-Repo-Tool
   3. ./mirror.sh

   Input:
   -----
    1) Absolute path to ${source_info_file} containing URL of the source
       repository in the following format.

       url: "git@github.com:kartven2/Puzzle.git"

      For ex: Path to file such as gogradle.lock

    2) ${credentials} of user with read and write access of both source and
       destination repository. User MUST also add his/her SSH Keys into
       both the source and destination GitHub accounts.

    3) ${dest_project} Destination GitHub project.
       For ex: git@github.com:destination

   Output:
   ------
    1) All the repositories specified in the ${source_info_file} will be mirrored
       into ${dest_project}.

    2) A new ${_new_info_file} file containing update URL pointing to repository
       in ${dest_project}.
