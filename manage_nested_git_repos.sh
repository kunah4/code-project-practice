#!/bin/sh
# Script to temporarily convert nested git repositories to regular directories

# Configuration
BACKUP_DIR="/tmp/git_backups_$(date +%Y%m%d_%H%M%S)"
BACKUP_MAP_FILE="$BACKUP_DIR/backup_map.txt"

# Function to check if a directory is a git repository
is_git_repo() {
    if [ -d "$1/.git" ]; then
        return 0
    else
        return 1
    fi
}

# Function to backup and remove .git directory
backup_and_remove_git() {
    dir="$1"
    if is_git_repo "$dir"; then
        echo "Found git repository in: $dir"
        
        # Create backup directory if it doesn't exist
        mkdir -p "$BACKUP_DIR"
        
        # Create unique backup name
        backup_name=$(echo "$dir" | tr '/' '_')
        backup_path="$BACKUP_DIR/$backup_name"
        
        # Backup .git directory
        echo "Backing up to: $backup_path"
        cp -r "$dir/.git" "$backup_path"
        
        # Record mapping for restoration
        echo "$dir|$backup_path" >> "$BACKUP_MAP_FILE"
        
        # Remove .git directory
        echo "Removing .git directory from: $dir"
        rm -rf "$dir/.git"
        
        echo "Converted to regular directory: $dir"
    else
        echo "Not a git repository: $dir"
    fi
}

# Function to restore .git directories
restore_git_directories() {
    if [ ! -f "$BACKUP_MAP_FILE" ]; then
        echo "No backup map file found at: $BACKUP_MAP_FILE"
        return 1
    fi
    
    echo "Restoring .git directories..."
    
    while IFS='|' read -r original_dir backup_path; do
        if [ -d "$backup_path" ]; then
            echo "Restoring: $original_dir"
            cp -r "$backup_path" "$original_dir/.git"
            echo "Restored .git directory to: $original_dir"
        else
            echo "Warning: Backup not found at: $backup_path"
        fi
    done < "$BACKUP_MAP_FILE"
    
    echo "Restoration complete!"
}

# Function to clean up backups
cleanup_backups() {
    if [ -d "$BACKUP_DIR" ]; then
        echo "Cleaning up backups at: $BACKUP_DIR"
        rm -rf "$BACKUP_DIR"
        echo "Cleanup complete!"
    else
        echo "No backups to clean up"
    fi
}

# Function to process all nested git repos
process_all_nested_repos() {
    echo "Finding all nested git repositories..."
    
    # Find all .git directories except the main one
    find . -type d -name ".git" -not -path "./.git" -prune | while read -r git_dir; do
        dir=$(dirname "$git_dir")
        backup_and_remove_git "$dir"
    done
}

# Function to process a specific directory
process_directory() {
    target_dir="$1"
    
    if [ -z "$target_dir" ]; then
        echo "Error: No directory specified"
        return 1
    fi
    
    if [ ! -d "$target_dir" ]; then
        echo "Error: Directory does not exist: $target_dir"
        return 1
    fi
    
    backup_and_remove_git "$target_dir"
}

# Main function
main() {
    case "$1" in
        "backup")
            shift
            if [ "$1" = "--all" ]; then
                echo "Backing up all nested git repositories..."
                process_all_nested_repos
            else
                echo "Backing up specific directory..."
                process_directory "$1"
            fi
            echo ""
            echo "Backups stored in: $BACKUP_DIR"
            echo "You can now add files to your main repository"
            ;;
            
        "restore")
            echo "Restoring git directories from backup..."
            restore_git_directories
            ;;
            
        "cleanup")
            echo "Cleaning up backup files..."
            cleanup_backups
            ;;
            
        "--help"|"-h"|"")
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  backup [--all | directory_path]  Backup and remove .git directories"
            echo "  restore                          Restore .git directories from backup"
            echo "  cleanup                          Remove backup files"
            echo ""
            echo "Examples:"
            echo "  $0 backup --all                  Backup all nested git repos"
            echo "  $0 backup path/to/repo           Backup specific repo"
            echo "  $0 restore                       Restore all backups"
            echo "  $0 cleanup                       Clean up temporary files"
            echo ""
            echo "Workflow:"
            echo "  1. Run: $0 backup --all"
            echo "  2. Add and commit to main repo: git add . && git commit -m 'message'"
            echo "  3. Push to remote: git push origin main"
            echo "  4. Restore nested repos: $0 restore"
            echo "  5. Clean up (optional): $0 cleanup"
            exit 0
            ;;
            
        *)
            echo "Unknown command: $1"
            echo "Use '$0 --help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"