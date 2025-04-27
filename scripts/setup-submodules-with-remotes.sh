#!/bin/sh
# POSIX compliant script to set up Git submodules from YAML config

# Function to check if required tools are installed
check_dependencies() {
    if ! command -v git >/dev/null 2>&1; then
        echo "Error: git is not installed"
        exit 1
    fi
    
    # Check for YAML parser (we'll use a simple one that works with awk)
    if ! command -v awk >/dev/null 2>&1; then
        echo "Error: awk is not installed"
        exit 1
    fi
}

# Function to check if a submodule already exists
check_submodule_exists() {
    submodule_path="$1"
    
    # Check if .gitmodules exists and contains the submodule
    if [ -f ".gitmodules" ]; then
        if grep -q "path = $submodule_path" .gitmodules 2>/dev/null; then
            return 0  # Submodule exists
        fi
    fi
    
    # Check if directory exists and is a git repo
    if [ -d "$submodule_path/.git" ]; then
        return 0  # Git repo exists in path
    fi
    
    return 1  # Submodule doesn't exist
}

# Function to parse YAML and add submodules
parse_and_add_submodules() {
    config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo "Error: Config file '$config_file' not found"
        exit 1
    fi
    
    # Parse YAML using awk
    awk '
    BEGIN { in_submodule = 0 }
    
    /^[[:space:]]*-[[:space:]]*name:/ {
        in_submodule = 1
        name = $NF
        gsub(/"/, "", name)
        gsub(/'\''/, "", name)
    }
    
    in_submodule && /^[[:space:]]*url:/ {
        url = $0
        sub(/^[[:space:]]*url:[[:space:]]*/, "", url)
        gsub(/"/, "", url)
        gsub(/'\''/, "", url)
    }
    
    in_submodule && /^[[:space:]]*path:/ {
        path = $0
        sub(/^[[:space:]]*path:[[:space:]]*/, "", path)
        gsub(/"/, "", path)
        gsub(/'\''/, "", path)
    }
    
    in_submodule && /^[[:space:]]*branch:/ {
        branch = $0
        sub(/^[[:space:]]*branch:[[:space:]]*/, "", branch)
        gsub(/"/, "", branch)
        gsub(/'\''/, "", branch)
        
        # Print the submodule info
        print name "|" url "|" path "|" branch
        in_submodule = 0
    }
    ' "$config_file" | while IFS='|' read -r name url path branch; do
        if [ -n "$name" ] && [ -n "$url" ] && [ -n "$path" ]; then
            if check_submodule_exists "$path"; then
                echo "Submodule '$name' at '$path' already exists, skipping..."
            else
                echo "Adding submodule '$name' from '$url' to '$path'"
                
                # Create parent directories if they don't exist
                mkdir -p "$(dirname "$path")"
                
                if [ -n "$branch" ]; then
                    git submodule add -b "$branch" "$url" "$path"
                else
                    git submodule add "$url" "$path"
                fi
                
                if [ $? -eq 0 ]; then
                    echo "Successfully added submodule '$name'"
                else
                    echo "Failed to add submodule '$name'"
                fi
            fi
        fi
    done
}

# Function to initialize main repo if needed
init_main_repo() {
    if [ ! -d ".git" ]; then
        echo "Initializing main repository..."
        git init
        
        if [ $? -ne 0 ]; then
            echo "Failed to initialize main repository"
            exit 1
        fi
    else
        echo "Main repository already initialized"
    fi
}

# Main execution
main() {
    config_file="git-submodules.yaml"
    
    # Check for custom config file argument
    if [ "$#" -eq 1 ]; then
        config_file="$1"
    fi
    
    echo "Using config file: $config_file"
    
    # Check dependencies
    check_dependencies
    
    # Initialize main repo
    init_main_repo
    
    # Parse YAML and add submodules
    parse_and_add_submodules "$config_file"
    
    # Commit if there are changes
    if git status --porcelain | grep -q .; then
        echo "Committing submodule additions..."
        git add .
        git commit -m "Added/updated submodules from $config_file"
    else
        echo "No changes to commit"
    fi
    
    echo "Setup complete!"
}

# Run main function with all arguments
main "$@"