#!/usr/bin/bash
GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

# Check if we're inside a Git repository
if git rev-parse --git-dir &>/dev/null; then
    gitdir="$(git rev-parse --show-toplevel)"
    
    # Check if there are any changes to commit
    if [ -z "$(git -C "$gitdir" status --porcelain)" ]; then
        echo -e "${GREEN}No changes to commit. Repository is already up-to-date.${RESET}"
        exit 0
    fi

    # Set default commit message if none is provided
    if [ -z "$1" ]; then
        printf "Commit message : "
        read message
        if [ -z "$message" ]; then 
            message="Saved the $(date +"%Y-%m-%d at %H:%M:%S") from $(hostname)"
        fi
    else
    message="$@"
    fi

    # Add changes to the staging area
    git -C "$gitdir" add . > /dev/null 2>&1 || { echo -e "${RED}Failed to add files to the repository.${RESET}"; exit 1; }

    # Commit the changes
    git -C "$gitdir" commit -m "$message" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to commit changes.${RESET}"
        exit 1
    fi

    # Push the changes to the remote repository
    output=$(git push 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to push changes to the repository.${RESET}"
        echo -e "${RED}$output${RESET}"  # Show the actual error message from git push
        exit 1
    fi

    # Provide feedback on the push result
    if [[ "$output" == *"Everything up-to-date"* ]]; then
        echo -e "${GREEN}Already up-to-date!${RESET}"
    else
        echo -e "${GREEN}Work saved successfully!${RESET}"
    fi
    
else
    # If not inside a Git repository
    echo -e "${RED}Not in a Git repository.${RESET}"
    exit 1
fi
