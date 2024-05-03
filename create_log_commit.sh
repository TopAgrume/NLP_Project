#!/bin/bash
# AUTHOR: Alexandre DR


# Function to handle interruption signal SIGINT
interrupt_handler() {
    echoc $RED "\nCtrl+C detected. Deleting current commit file."
    [ -e "$commit_file" ] && rm "$commit_file"
    exit 1
}
# Trap interruption signal SIGINT
trap interrupt_handler SIGINT

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
    echo "Usage: $0 [OPTIONS] <type(string)> [<dest_file(path)>]"
    echo "Args:"
    echo "  type          Specify the type of operation (e.g., 'feat', 'fix', etc.)"
    echo "  dest_file     The .md file in which to add the logs (e.g., changelog.md)"
    echo
    echo "Options:"
    echo "  --help        Display this help message"
    echo "  -v            Enable verbose mode"
    echo "  -d            Disable tag"
    echo
    echo "Example: $0 -v style /path/to/changelog.md"
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

# Function to check file existence
check_file_exists() {
    local file=$1
    [ -f "$file" ] || { echoc $RED "Provided path '$file' does not exist"; exit 1; }
}

# Crash if not enough parameters are provided
if [ $# -eq 0 ]; then
    echoc $RED "Usage: $0 [OPTIONS] <type(string)> [<destination_file(path)>]"
    echoc $RED "Command --help will provide help."
    exit 1
fi

verbose=1
disable_tag=1
dest_file=""
default_type=""

# Parse input options, set flags, type and destination file
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --help)
        help_message; exit 0 ;;
    -v)
        verbose=0 ;;
    -d)
        disable_tag=0 ;;
    -vd | -dv)
        verbose=0
        disable_tag=0 ;;
    -*)
        echoc $RED "Unknown option '$1'. Command --help will provide help."
        exit 1 ;;
    *)
        # Set the type or destination file
        if [ -z "$default_type" ]; then
            default_type="$1"
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

# Give information when verbose=0
logger() {
    if [ $verbose -eq 0 ]; then
        echo -e "$1"
    fi
}

# Commit convention link
link=https://www.conventionalcommits.org/en/v1.0.0/

# Define the default messages for each keyword
declare -A default_messages=(
    ["feat"]="New features"
    ["fix"]="Bug Fixes"
    ["update"]="Update existing feature"
    ["refactor"]="Code refactoring"
    ["style"]="Code style changes (formatting, etc.)"
    ["tests"]="Add or modify tests"
    ["docs"]="Documentation changes"
    ["remove"]="Delete existing feature"
    ["chore"]="Routine tasks, maintenance, etc."
    ["perf"]="Performance improvements"
    ["deps"]="Dependency updates"
)

# Create the file name with a little hash
commit_file=$(mktemp "/tmp/COMMIT_XXXXXX.yaml")

# Get the modified files
untracked_files=($(git status -s | grep '^\??' | awk '{print $2}'))
modified_files=($(git status -s | grep '^ M' | awk '{print $2}'))
added_files=($(git status -s | grep '^A' | awk '{print $2}'))
removed_files=($(git status -s | grep '^ D' | awk '{print $2}'))

# Write inside the commit file
write() {
    echo -e "$1" >> "$commit_file"
}

# Display modified files
display_files() {
    local title="$1"
    shift
    local files=("$@")
    if [ "${#files[@]}" -ne 0 ]; then
        write "\n$title:"
        for file in "${files[@]}"; do
            write "$file) # [...]"
        done
    fi
}

# Pattern matching on given keyword
get_default_message() {
    local keyword="$1"

    case "$keyword" in
        "feat"|"fix"|"update"|"refactor"|"style"|"tests"|"docs"|"chore"|"remove"|"perf"|"deps")
            echo "$keyword: ${default_messages[$keyword]}" ;;
        *)
            echo "$keyword: " ;;
    esac
}

# Displays the user guide
print_possibilities() {
    echoc $BLUE "\nInstructions:"
    echo " - Use the conventional commit format"
    echo " - Message example: 'feat(lang): add Polish language'"
    echoc $RED " - Saving the file will generate logs and commit the listed modified files"

    echoc $BLUE "\nPossible 'type keywords' and their meanings:"
    for keyword in "${!default_messages[@]}"; do
        echoc $GREEN "[$keyword]" -n
        echo " - ${default_messages[$keyword]}"
    done

    echoc $RED "\nMake sure to include a \"!\" next to the modification type to indicate any breaking changes."
    echoc $RED "For example: " -n
    echo -n "'update(parser)"
    echoc $RED "!" -n
    echo ": swap token and value args'"

    echoc $BLUE "\nUseful link:"
    echo " - [Conventional Commits]($link)"

    # Display variables
    echoc $BLUE "\nCurrent selected options:"
    echopc $L_B " - Default Type:" "$default_type"
    echopc $L_B " - Destination Log File:" "$dest_file"
    echopc $L_B " - Verbose Mode (0 is True):" "$verbose"
    echopc $L_B " - Disable Tag (0 is True):" "$disable_tag"
}

clear; print_possibilities

# Display commit type
write "=== Commit Message Prompt ===\n"
write "Fill commit message:"
write "\"\"\""
write "$(get_default_message $default_type) ..."
write "\"\"\""

# Display modified files
display_files "Untracked files" "${untracked_files[@]/#/ - feat: (}"
display_files "Modified files" "${modified_files[@]/#/ - update: (}"
display_files "Added files" "${added_files[@]/#/ - update: (}"
display_files "Removed files" "${removed_files[@]/#/ - remove: (}"

# Open VSCode file at the commit message line
code -g $commit_file:5:50

# Wait for the file to be saved
initial_mtime=$(stat -c %Y "$commit_file")
while true; do
    current_mtime=$(stat -c %Y "$commit_file")
    if [ "$current_mtime" -le "$initial_mtime" ]; then
        sleep 1
        continue
    fi

    clear
    echoc $BLUE "\nTemporary file has been saved."
    break
done

# Get and display the commit message
first_line=$(grep -n \"\"\" $commit_file | awk -F: 'NR==1 {print $1}')
second_line=$(grep -n \"\"\" $commit_file | awk -F: 'NR==2 {print $1}')
commit_message=$(sed -n "$((first_line + 1)),$((second_line - 1))p" "$commit_file")
echoc $BLUE "Commit message content:"
echo $commit_message

types=()
files=()
desc=()
idx=0

# Get and display the modified files (parsing tokens)
echoc $BLUE "\nRecorded files: "
regex='^[ -]+([a-zA-Z!]+):[ ]*\(([^)]+)\)[ ]*(.*)$'

# Tokens pretty print
while IFS= read -r line; do
    if [[ ! $line =~ $regex ]]; then
        logger "---- $line"
        continue
    fi

    types+=("${BASH_REMATCH[1]}")
    files+=("${BASH_REMATCH[2]}")
    description="${BASH_REMATCH[3]}"

    # Print and store the extracted information
    if [ "$description" == "" ] || [[ "$description" =~ ^[[:space:]]*# ]]; then
        echoc $RED "!!!!   " -n
        echopc $L_B "Type:" "${types[$idx]}, " -n
        echopc $L_B "Path:" "${files[$idx]}, " -n
        echoc $RED "no-log"
        desc+=("")
    else
        echoc $GREEN "####   " -n
        echopc $L_B "Type:" "${types[$idx]}, " -n
        echopc $L_B "Path:" "${files[$idx]}, " -n
        echopc $L_B "Description:" "$description"
        desc+=("$description")
    fi
    ((idx+=1))
done < "$commit_file"

# Deleting temporary file
rm $commit_file

echoc $BLUE "\nTemporary file " -n
echo -n "'$commit_file'"
echoc $BLUE " deleted."

# Define the markdown value for each type keyword
declare -A changelog_category=(
    ["feat"]="New Features"
    ["fix"]="Bug Fixes"
    ["update"]="Updates"
    ["refactor"]="Code refactoring"
    ["style"]="Stylistic Changes"
    ["tests"]="Testing"
    ["docs"]="Documentation"
    ["remove"]="Removals"
    ["chore"]="Maintenance"
    ["perf"]="Performance improvements"
    ["deps"]="Dependency updates"
    ["!"]="Breaking changes"
)

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
        echopc $BLUE "Adding new key to changelog file:" "\"$title_pattern\""
        sed -i "4i $title_pattern" "$dest_file"
    fi
}

# Function to perform Git add operation
git_add_files() {
    echoc $BLUE "Git add files..."
    for file in "${files[@]}"; do
        logger "git add --all: $file"
        # Uncomment the following line for actual use
        git add --all "$file"
    done
    git add --all "$dest_file"
}

# Function to perform Git commit operation
git_commit_files() {
    echoc $BLUE "Git commit added files..."
    logger "git commit -m \"$commit_message\""
    # Uncomment the following line for actual use
    git commit -m "$commit_message"
}

# Function to write logs to the changelog file
# >> This part can be optimized by building the string blocks
# >> by type and injecting them only once for each type
write_logs_to_changelog() {
    local nb_skipped=0
    for ((i=0; i<${#types[@]}; i++)); do
        # Skip tokens without description (no-log)
        if [ "${desc[$i]}" == "" ]; then
            logger "(log skipped) ${files[$i]}"
            ((nb_skipped += 1))
            continue
        fi

        # Find the write location and add the tokens
        local pattern=""
        if [[ "${types[$i]}" =~ .*\!$ ]]; then
            # Detect breaking changes
            pattern="### ${changelog_category["!"]}"
        else
            pattern="### ${changelog_category[${types[$i]}]}"
        fi
        add_changelog_key "$pattern"
        local line_number=$(grep -nm 1 "$pattern" "$dest_file" | awk -F: 'NR==1 {print $1}')

        local new_line=" - ($(basename ${files[$i]})) ${desc[$i]}"
        sed -i "$((line_number + 1))i $new_line" "$dest_file"
    done

    echoc $BLUE "Number of files ignored by logs: " -n
    echoc $WHITE "$nb_skipped\n"
}

write_logs_to_changelog

# Read and create a new tag in destination file
if [ $disable_tag -eq 1 ]; then
    echoc $WHITE "Do you want to package all the changes so far in the logs into a new tag ?"
    echoc $WHITE "Give the name of the tag (ex: 2.2.8dev), otherwise pass: " -n
    read version
fi

# Write new tag inside logs
if [ "$version" != "" ] && [ "$version" != "n" ]; then
    current_date=$(date +'%Y-%m-%d')
    new_tag="[$version] - $current_date"
    sed -i "4i ## $new_tag" "$dest_file"

    echoc $BLUE "New tag added: " -n
    echo "$new_tag"
fi

git_add_files
git_commit_files
echoc $BLUE "Operation complete!"
