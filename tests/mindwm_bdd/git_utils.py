from git import Repo
import shutil
import os

def git_clone(dest_dir, git_url, git_branch, git_commit):
    try:
        if os.path.exists(dest_dir):
            print(f"Destination directory '{dest_dir}' already exists. Removing it...")
            shutil.rmtree(dest_dir)

        # Clone the repository to the destination directory
        print(f"Cloning branch '{git_branch}' from '{git_url}' to '{dest_dir}'...")
        repo = Repo.clone_from(git_url, dest_dir, branch=git_branch)

        # Checkout the specific commit
        print(f"Checking out commit '{git_commit}'...")
        repo.git.checkout(git_commit)

        print(f"Successfully cloned commit '{git_commit}' to '{dest_dir}'.")
    except Exception as e:
        print(f"An error occurred: {e}")


