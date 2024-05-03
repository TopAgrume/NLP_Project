#!/bin/bash
# AUTHOR: Alexandre DR

# Function to handle interruption signal SIGINT
interrupt_handler() {
    echoc $RED "\nCtrl+C detected. Task aborted."
    exit 1
}
# Trap interruption signal SIGINT
trap interrupt_handler SIGINT

# TODO:Give tag as param and path
verbose=1

# Colors
BLUE='\033[1;34m'
GREEN='\e[1;32m'
RED='\033[0;31m'
L_B='\e[1;36m'
YELLOW='\e[0;33m'
WHITE='\e[1;37m'
RESET='\033[0m'

# Help message when --help is used
help_message() {
    echo "Usage: $0 [OPTION] <tag(string)> [<dest_file(path)>]"
    echo "Args:"
    echo "  tag           Specify the new tag in changelog file (e.g., '0.2.5dev')"
    echo "  dest_file     The .md file in which to add the logs (e.g., changelog.md)"
    echo
    echo "Option:"
    echo "  --help        Display this help message"
    echo "  -v            Enable verbose mode"
    echo
    echo "Example: $0 -v 2.8.12ref /path/to/changelog.md"
}

# echo with colors
echoc() {
    local color=$1
    local message=$2
    local option=$3
    echo -e $option "$color$message$RESET"
}

# echo pair with colors
echopc() {
    local color=$1
    local message1=$2
    local message2=$3
    local option=$4
    echo -e $option "$color$message1$RESET" "$message2"
}

# Give information when verbose=0
logger() {
    if [ $verbose -eq 0 ]; then
        echo -e "$1"
    fi
}

# Function to check file existence
check_file_exists() {
    local file=$1
    [ -f "$file" ] || { echoc $RED "Provided path '$file' does not exist"; exit 1; }
}

# Crash if not enough parameters are provided
if [ $# -eq 0 ]; then
    echoc $RED "Usage: $0 [OPTION] <type(string)> [<destination_file(path)>]"
    echoc $RED "Command --help will provide help."
    exit 1
fi

verbose=1
version=""
dest_file=""

# Parse input options, set flags, type and destination file
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --help)
        help_message; exit 0 ;;
    -v)
        verbose=0 ;;
    -*)
        echoc $RED "Unknown option '$1'. Command --help will provide help."
        exit 1 ;;
    *)
        # Set the type or destination file
        if [ -z "$version" ]; then
            version="$1"
        elif [ -z "$dest_file" ]; then
            check_file_exists "$1"
            dest_file="$1"
        else
            echoc $RED "Error: Unexpected argument '$1'"
            help_message; exit 1
        fi
        ;;
    esac
    shift
done

# Crash if pwd is not a git repository
if [ ! -d "./.git" ]; then
    echoc $RED "This is not a git repository. Task aborted."
    exit 1
fi

# Assign default dest file or create it
if [ -z "$dest_file" ]; then
    dest_file="changelog.md"
    if [ ! -e "$dest_file" ] && [ -e "docs/source/changelog.md" ]; then
        dest_file="docs/source/changelog.md"
    elif [ ! -e "$dest_file" ]; then
        echo "# Changelog" > "$dest_file"
        echo -e "All notable changes to this project will be documented in this file.\n\n" >> "$dest_file"
    fi
fi


titles=()
descriptions=()
directory="logs"

# Find key, value pairs inside log files
for file in "$directory"/*; do
    if [ -f "$file" ]; then
        logger "-- parsing: $file"
        while read -r title && read -r description; do
            titles+=("$title")
            descriptions+=("$description")
        done < <(awk '/^###/{category=$0; next} NF{print category; print "- " $0}' $file)
    fi
done

# Print the titles and descriptions
# Uncomment to debug hard
#for ((i=0; i<${#titles[@]}; i++)); do
#    logger "Title: ${titles[i]}"
#    logger "Description: ${descriptions[i]}"
#done

echoc $BLUE "Writting logs inside " -n
echo -n "'$dest_file'"
echoc $BLUE " file."

# Function for adding a key to the changelog file
add_changelog_key() {
    local title_pattern="$1"
    last_tag=$(grep -nm 1 '^## \[.*\]' "$dest_file" | awk -F: 'NR==1 {print $1}')
    last_title=$(grep -nm 1 "$title_pattern" "$dest_file" | awk -F: 'NR==1 {print $1}')

    if [ -z "$last_tag" ] && [ ! -z "$last_title" ]; then
        return;
    fi

    if { [ -z "$last_tag" ] && [ -z "$last_title" ]; } ||
        [ -z "$last_title" ] || [ "$last_tag" -lt "$last_title" ]; then
        echopc $L_B "Adding new key:" "\"$title_pattern\""
        sed -i "4i $title_pattern" "$dest_file"
    fi
}

# Function to write logs to the changelog file
# >> This part can be optimized by building the string blocks
# >> by type and injecting them only once for each type
write_logs_to_changelog() {
    local nb_log=0
    for ((i=0; i<${#titles[@]}; i++)); do
        # Find the write location and add the tokens
        local pattern="${titles[$i]}"
        add_changelog_key "$pattern"
        local line_number=$(grep -nm 1 "$pattern" "$dest_file" | awk -F: 'NR==1 {print $1}')

        local new_line="${descriptions[$i]}"
        sed -i "$((line_number + 1))i $new_line" "$dest_file"
        ((nb_log+=1))
    done

    echoc $BLUE "Number of logs added in '$dest_file': " -n
    echoc $WHITE "$nb_log\n"
}

write_tag_to_changelog() {
    if [ "$version" != "" ] && [ "$version" != "n" ]; then
        current_date=$(date +'%Y-%m-%d')
        new_tag="[$version] - $current_date"
        sed -i "4i ## $new_tag" "$dest_file"

        echoc $BLUE "New tag added: " -n
        echo "$new_tag"
    fi
}

write_logs_to_changelog
write_tag_to_changelog

# Delete old logs
rm "$directory"/*

# Function to perform Git add operation
git_add_files() {
    echoc $BLUE "Git add $dest_file"
    git add --all "$dest_file"
    git add --all "$directory"
}

# Function to perform Git commit operation
git_commit_files() {
    echoc $BLUE "Git commit added file"
    git commit -m "update(changelog): '$dest_file' updated for new version, old logs deleted"
}

git_add_files
git_commit_files

echoc $BLUE "Operation complete!"