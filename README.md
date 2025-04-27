# Coding Projects Practice
Learn/Review topics below and more using Rust first.
 - HTTP Server (TCP, Sockets, headers, request, response, concurrent connections, persistent connections, ...)
 - SQLite (SQL syntax, B-tree, table scan, indexe, ...)
 - Git
 - Interpreter (ASTs, tree-walk interpreters, tokenization, ...)
 - Shell (REPL, POSIX compliance, parsing shell commands, executing programs, ...)



## 
1. Uses a temporary directory for backups
2. Provides a way to restore the `.git` directories after you've pushed to GitLab/GitHub

This improved script provides a complete workflow for managing nested Git repositories. Here's the recommended process:

1. **Backup and remove `.git` directories before pushing to GitLab/GitHub**:
   ```bash
   ./manage_nested_git_repos.sh backup --all
   ```

2. **Add files to your main repository and push**:
   ```bash
   git add .
   git commit -m "Add project files"
   git push origin main
   ```

3. **Restore the `.git` directories after pushing**:
   ```bash
   ./manage_nested_git_repos.sh restore
   ```

4. **Clean up temporary backups (optional)**:
   ```bash
   ./manage_nested_git_repos.sh cleanup
   ```

The script:
- Uses `/tmp` for temporary backups
- Creates a mapping file to track original locations
- Provides separate commands for backup, restore, and cleanup
- Handles both individual directories and all nested repos

This approach lets you maintain your local Git repositories while pushing a clean version to GitLab/GitHub without submodule complications.