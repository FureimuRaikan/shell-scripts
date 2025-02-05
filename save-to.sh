#!/usr/bin/bash
# Color definitions for output
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

# Get the currently authenticated GitHub user
User=$(gh auth status | awk '$2 == "Logged" && $6 == "account" {print $7}')


# Retrieve the list of repositories from GitHub using GitHub CLI
RepoList=$(gh repo list)

# Check if the repository list retrieval was successful
if [ $? -ne 0 ]; then
	echo -e "${RED}Failed to retrieve repository list.${RESET}"
	exit 1
fi

# Check if the repository list is empty (no repositories found)
if [ -z "$RepoList" ]; then
	echo -e "${RED}No repositories found.${RESET}"
	exit 1
fi

# Extract the repository names from the list
RepoList=$(echo "$RepoList" | awk -F'/' '{print $2}' | awk '{print $1}')

# Check if the user is authenticated with GitHub
if [ -z "$User" ]; then
	echo -e "${RED}Not logged in to GH.${RESET}"
	exit
fi

# Check if the current directory is a Git repository
if git rev-parse --git-dir &>/dev/null; then
	# Define the path for the temporary repository clone
	TempRepo=$(echo "$(dirname $(git rev-parse --show-toplevel))/temp_repo")
	
	# Get the absolute path of the current Git repository
	path_from=$(git rev-parse --show-toplevel)
	
	# If no repository name is provided as an argument, prompt the user to select a repository
	if [ -z "$1" ]; then
		while true; do
			# Ask the user to input the name of the repository to save to
			printf "Repository to save to : "
			read input

			# Check if the selected repository exists in the list
			if echo "$RepoList" | grep -w -q "$input"; then
				# Check if the current repository is the same as the selected one
				if [[ $(git remote get-url origin | sed 's/.*\///; s/.git$//') == "$input" ]]; then
					echo -e "${RED}Already in $input.${RESET}"
					exit
				fi

				# Ask for the commit message
				printf "Commit message : "
				read commit_message

				# If no commit message is provided, use a default message with date and hostname
				if [ -z "$commit_message" ] ; then
					commit_message="Saved the $(date +"%Y-%m-%d at %H:%M:%S") from $(hostname)"
				fi

				# Check if the temporary repository directory exists and remove it if necessary
				if [ -d "$TempRepo" ]; then
					echo -e "${YELLOW}Directory $TempRepo already exists. Removing it...${RESET}"
					rm -rf "$TempRepo" || { echo -e "${RED}Failed to remove existing directory $TempRepo.${RESET}"; exit 1; }
				fi

				# Clone the selected repository into the temporary directory
				echo "Cloning repository $input..."
				gh repo clone $User/$input $TempRepo || { echo -e "${RED}Failed to clone repository $input.${RESET}"; rm -rf "$TempRepo" ; exit 1; }

				# Sync the local repository with the temporary repository (excluding .git files)
				rsync -av --delete --exclude='.git*' $path_from/ $TempRepo/ || { echo -e "${RED}Failed to sync files with rsync.${RESET}"; rm -rf "$TempRepo" ; exit 1; }

				if [ -z "$(git -C $TempRepo status --porcelain)" ]; then
				# No changes detected, notify the user
					echo -e "${GREEN}No changes detected. Nothing to commit.${RESET}"
				# Remove temporary repository and exit
					rm -rf $TempRepo || { echo -e "${RED}Failed to remove temporary directory $TempRepo.${RESET}"; exit 1; }
					exit 0
				fi
				
				# Add all changes in the temporary repository
				git -C $TempRepo add . || { echo -e "${RED}Failed to add files to the repository.${RESET}"; rm -rf "$TempRepo" ; exit 1; }

				# Commit the changes in the temporary repository
				git -C $TempRepo commit -m "$commit_message" || { echo -e "${RED}Failed to commit changes.${RESET}"; rm -rf "$TempRepo" ; exit 1; }

				# Push the changes to the remote repository
				output=$(git -C $TempRepo push) || { echo -e "${RED}Failed to push changes to the repository.${RESET}"; rm -rf "$TempRepo" ; exit 1; }

				# Check if the repository is already up-to-date
				if [[ "$output" == *"Everything up-to-date"* ]]; then
					echo -e "${GREEN}Already up-to-date !${RESET}"
				else
					echo -e "${GREEN}Work saved successfully !${RESET}"
				fi

				# Remove the temporary directory after completing the operation
				rm -rf $TempRepo || { echo -e "${RED}Failed to remove temporary directory $TempRepo.${RESET}"; exit 1; }
				break
			else
				# If the selected repository doesn't exist in the list, display an error
				echo -e "${RED}'$input' doesn't exist.\n${YELLOW}Existing repositories:\n${BLUE}$RepoList${RESET}"
			fi
		done
	
	# If a repository name is provided as an argument
	else
		# Keep asking for a valid repository name if the provided one doesn't exist
		input=$1
		
		while ! echo "$RepoList" | grep -w -q "$input"; do
			echo -e "${RED}'$input' doesn't exist.\n${YELLOW}Existing repositories:\n${BLUE}$RepoList${RESET}"
			printf "Repository to save to : "
			read input

			set -- "$input"
		done

		# Check if the current repository is the same as the selected one
		if [[ $(git remote get-url origin | sed 's/.*\///; s/.git$//') == "$input" ]]; then
			echo -e "${RED}Already in $input.${RESET}"
			exit
		fi

		# Ask for the commit message
		printf "Commit message : "
		read commit_message

		# Use the default commit message if none is provided
		if [ -z "$commit_message" ] ; then
			commit_message="Saved the $(date +"%Y-%m-%d at %H:%M:%S") from $(hostname)"
		fi

		# Check if the temporary repository directory exists and remove it if necessary
		if [ -d "$TempRepo" ]; then
			echo -e "${YELLOW}Directory $TempRepo already exists. Removing it...${RESET}"
			rm -rf "$TempRepo" || { echo -e "${RED}Failed to remove existing directory $TempRepo.${RESET}"; exit 1; }
		fi

		# Clone the selected repository into the temporary directory
		echo "Cloning repository $input..."
		gh repo clone $User/$input $TempRepo || { echo -e "${RED}Failed to clone repository $input.${RESET}"; rm -rf "$TempRepo" ; exit 1; }

		# Sync the local repository with the temporary repository (excluding .git files)
		rsync -av --delete --exclude='.git*' $path_from/ $TempRepo/ || { echo -e "${RED}Failed to sync files with rsync.${RESET}"; rm -rf "$TempRepo" ; exit 1; }

		if [ -z "$(git -C $TempRepo status --porcelain)" ]; then
		# No changes detected, notify the user
			echo -e "${GREEN}No changes detected. Nothing to commit.${RESET}"
		# Remove temporary repository and exit
			rm -rf $TempRepo || { echo -e "${RED}Failed to remove temporary directory $TempRepo.${RESET}"; exit 1; }
			exit 0
		fi

		# Add all changes in the temporary repository
		git -C $TempRepo add . || { echo -e "${RED}Failed to add files to the repository.${RESET}"; rm -rf "$TempRepo" ; exit 1; }

		# Commit the changes in the temporary repository
		git -C $TempRepo commit -m "$commit_message" || { echo -e "${RED}Failed to commit changes.${RESET}"; rm -rf "$TempRepo" ; exit 1; }

		# Push the changes to the remote repository
		output=$(git -C $TempRepo push) || { echo -e "${RED}Failed to push changes to the repository.${RESET}"; rm -rf "$TempRepo" ; exit 1; }

		# Check if the repository is already up-to-date
		if [[ "$output" == *"Everything up-to-date"* ]]; then
			echo -e "${GREEN}Already up-to-date !${RESET}"
		else
			echo -e "${GREEN}Work saved successfully !${RESET}"
		fi

		# Remove the temporary directory after completing the operation
		rm -rf $TempRepo || { echo -e "${RED}Failed to remove temporary directory $TempRepo.${RESET}"; exit 1; }
		break
	fi

else
	# If the current directory is not a Git repository, notify the user
	echo -e "${RED}Not in a Git repository.${RESET}"
fi
