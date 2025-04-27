#!/usr/bin/env python3
"""
Git Submodule Setup Script using YAML Configuration
Manages Git submodules based on a YAML configuration file.
"""

import os
import sys
import yaml
import subprocess
from pathlib import Path
from typing import Dict, List, Optional


def check_submodule_exists(path: str) -> bool:
    """Check if a submodule already exists at the given path."""
    # Check if .gitmodules contains the path
    gitmodules_path = Path('.gitmodules')
    if gitmodules_path.exists():
        with open(gitmodules_path, 'r') as f:
            if f'path = {path}' in f.read():
                return True
    
    # Check if directory exists and is a git repo
    git_dir = Path(path) / '.git'
    return git_dir.exists()


def init_main_repo() -> None:
    """Initialize the main repository if it doesn't exist."""
    if not Path('.git').exists():
        print("Initializing main repository...")
        result = subprocess.run(['git', 'init'], capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Failed to initialize main repository: {result.stderr}")
            sys.exit(1)
    else:
        print("Main repository already initialized")


def add_submodule(submodule: Dict[str, str]) -> bool:
    """Add a single submodule based on configuration."""
    name = submodule.get('name')
    url = submodule.get('url')
    path = submodule.get('path')
    branch = submodule.get('branch')
    
    if not all([name, url, path]):
        print(f"Error: Missing required fields for submodule {name}")
        return False
    
    if check_submodule_exists(path):
        print(f"Submodule '{name}' at '{path}' already exists, skipping...")
        return False
    
    print(f"Adding submodule '{name}' from '{url}' to '{path}'")
    
    # Create parent directories if they don't exist
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    
    # Build git submodule add command
    cmd = ['git', 'submodule', 'add']
    if branch:
        cmd.extend(['-b', branch])
    cmd.extend([url, path])
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode == 0:
        print(f"Successfully added submodule '{name}'")
        return True
    else:
        print(f"Failed to add submodule '{name}': {result.stderr}")
        return False


def load_config(config_file: str) -> Dict:
    """Load and validate the YAML configuration file."""
    if not os.path.exists(config_file):
        print(f"Error: Config file '{config_file}' not found")
        sys.exit(1)
    
    try:
        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)
            
        if not config or 'submodules' not in config:
            print("Error: Invalid config file format. Missing 'submodules' key.")
            sys.exit(1)
            
        return config
    except yaml.YAMLError as e:
        print(f"Error parsing YAML file: {e}")
        sys.exit(1)


def main():
    """Main function to orchestrate submodule setup."""
    config_file = 'git-submodules.yaml'
    
    # Check for custom config file argument
    if len(sys.argv) > 1:
        config_file = sys.argv[1]
    
    print(f"Using config file: {config_file}")
    
    # Initialize main repo
    init_main_repo()
    
    # Load config
    config = load_config(config_file)
    
    # Process submodules
    changes_made = False
    for submodule in config['submodules']:
        if add_submodule(submodule):
            changes_made = True
    
    # Commit if there are changes
    if changes_made:
        print("Committing submodule additions...")
        subprocess.run(['git', 'add', '.'])
        subprocess.run(['git', 'commit', '-m', f"Added/updated submodules from {config_file}"])
    else:
        print("No changes to commit")
    
    print("Setup complete!")


if __name__ == "__main__":
    main()