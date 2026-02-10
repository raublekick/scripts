#!/usr/bin/env bash

# Default configuration
DOTFILES_DIR="${HOME}/.dotfiles"
DOTFILES_REPO=""
BACKUP_DIR="${HOME}/.dotfiles/backup"
AUTO_COMMIT=false
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/config"

BOLD=$(tput bold)
RESET=$(tput sgr0)

show_help() {
  cat << EOF
Usage: $(basename "$0") <command> [options]

Commands:
  help        Show this help message
  init        Initialize the dotfiles management system in the user's home directory. Creates the configuration file if it does not exist, and clones the specified repository.
              Usage: init [--repo <repository_url>] [--dir <dotfiles_directory>] [--auto-commit]
              Options:
                --repo <repository_url>       Specify the git repository URL to clone from (default: $DOTFILES_REPO)
                --dir <dotfiles_directory>    Specify the directory to store dotfiles (default: $DOTFILES_DIR). If the repository is specified, this directory will be used as the target for cloning, otherwise the directory will be created if it does not exist.
                --backup-dir <backup_directory> Specify the directory to store backups (default: $BACKUP_DIR)
                --auto-commit                 Enable automatic committing of changes to the repository (default: $AUTO_COMMIT)
  add         Add a file or directory to track for a package
              Usage: add <package> <file|directory>
  remove      Remove a package from tracking. Removes symlinks created, but keeps files in the dotfiles directory.
              Usage: remove <package>
  restore     Restore original files by removing symlinks and copying dotfiles directory back to their original locations.
              Usage: restore <package>
  list        List all tracked packages and their files.
              Usage: list [package] [--files|-f]
              Options:
                --files, -f    Show files for each package
EOF
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  fi
}

init() {
  # Configure defaults

  # Initialized from script defaults or loaded config file
  local repo=""
  local dir="${DOTFILES_DIR}"
  local auto_commit="${AUTO_COMMIT}"
  local backup_dir="${BACKUP_DIR}"
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        repo="$2"
        shift 2
        ;;
      --dir)
        dir="$2"
        shift 2
        ;;
      --backup-dir)
        backup_dir="$2"
        shift 2
        ;;
      --auto-commit)
        auto_commit=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done

  echo "Initializing..."
  echo -e "\tRepository: $repo"
  echo -e "\tDotfiles directory: $dir"
  echo -e "\tBackup directory: $backup_dir"
  echo -e "\tAuto commit: $auto_commit"
  
  # Create the config file if it doesn't exist
  if [[ ! -f "$CONFIG_FILE" ]]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    {
      echo "DOTFILES_DIR=\"$dir\""
      echo "DOTFILES_REPO=\"$repo\""
      echo "BACKUP_DIR=\"$backup_dir\""
      echo "AUTO_COMMIT=$auto_commit"
    } > "$CONFIG_FILE"
    echo "Configuration file created at $CONFIG_FILE"
  else
    echo "Configuration file already exists at $CONFIG_FILE. Skipping."
  fi

  # If the repo is set, try cloning, otherwise create the directory
  if [[ -z "$repo" ]]; then
    echo "Creating dotfiles directory: $dir"
    mkdir -p "$dir"
    echo "Creating backup directory: $backup_dir"
    mkdir -p "$backup_dir"
  else
    echo "Cloning repository: $repo into $dir"
    if [[ -d "$dir" ]]; then
      echo "Directory $dir already exists. Skipping clone."
    else
      git clone "$repo" "$dir"
      if [[ $? -ne 0 ]]; then
        echo "Error: Clone failed" >&2
        exit 1
      fi
    fi
  fi

  echo "Initialization complete."
}

add() {
  # Parse arguments to get package name and source file/directory to add
  local package="$1"
  local source="$2"
  local relative_source="$source" # Store the original relative path

  # Validate arguments
  if [[ -z "$package" || -z "$source" ]]; then
    echo "Usage: add <package> <file|directory>" >&2
    return
  fi
  # Check if the source path is absolute or relative. If it's relative, prepend the user's home directory to it.
  if [[ "$source" != /* ]]; then
    source="$HOME/$source" # make absolute
  else 
    relative_source="${source#$HOME/}" # make relative to home
  fi
  local source_dir="$(dirname "$relative_source")"
  echo "Creating package ${BOLD}$package${RESET} from $source"

  # check if symlink already exists in the user's home directory
  if [[ -L "$source" ]]; then
    echo "This package is already linked: $source and cannot be added again. Use ${BOLD}remove${RESET} to unlink it, or ${BOLD}restore${RESET} to restore the original files." >&2
    return
  fi

  # Does the file or directory exist in the user's home directory?
  if [[ ! -e "$source" ]]; then
    echo "File or directory does not exist in: $source" >&2
    return
  fi

  # Does the file or directoy exist in the dotfiles directory?
  if [[ -d "$DOTFILES_DIR/$package" ]]; then
    echo "Package directory already exists: $DOTFILES_DIR/$package. Contents of this package will be overwritten. Do you want to continue? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
      echo "No package has been added."
      return
    fi
  fi

  mkdir -p "$DOTFILES_DIR/$package/$source_dir"
  mkdir -p "$BACKUP_DIR/$package/$source_dir"
  
  echo "Moving $source to $DOTFILES_DIR/$package/$relative_source"
  cp -r "$source" "$BACKUP_DIR/$package/$relative_source"
  mv -r "$source" "$DOTFILES_DIR/$package/$relative_source"
  
  stow -d "$DOTFILES_DIR" -t "$HOME" "$package"

  if [[ "$AUTO_COMMIT" == true ]]; then
    git -C "$DOTFILES_DIR" add "$package"
    git -C "$DOTFILES_DIR" commit -m "Added package $package"
  fi
}

remove() { 
  local package="$1"
  if [[ -z "$package" ]]; then
    echo "Usage: remove <package>" >&2
    return
  fi

  if [[ ! -d "$DOTFILES_DIR/$package" ]]; then
    echo "Package not found: $package" >&2
    return
  fi

  stow -d "$DOTFILES_DIR" -t "$HOME" -D "$package"
  
  echo "Package $package has been unlinked successfully."
}

restore() {
  local package="$1"
  if [[ -z "$package" ]]; then
    echo "Usage: restore <package>" >&2
    return
  fi

  remove "$package"

  cp -r "$DOTFILES_DIR/$package/." "$HOME/"  

  echo "Package $package has been restored successfully."
}

list() {
  local package=""
  local show_files=false
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --files|-f)
        show_files=true
        shift
        ;;
      *)
        package="$1"
        shift
        ;;
    esac
  done

  # list the packages based on directories in DOTFILES_DIR
  if [[ -n "$package" ]]; then
    echo "Files for package $package:"
    if [[ -d "$DOTFILES_DIR/$package" ]]; then
      ls -1 "$DOTFILES_DIR/$package"
    else
      echo "Package not found: $package" >&2
    fi
  else
    if [[ -d "$DOTFILES_DIR" ]]; then
      if $show_files; then
        if compgen -G "$DOTFILES_DIR/*/" > /dev/null; then
          for pkg_dir in "$DOTFILES_DIR"/*/; do
            pkg_name=$(basename "$pkg_dir")
            echo "Package: $pkg_name"
            ls -1 "$pkg_dir"
            echo ""
          done
        else
          echo "No packages found."
        fi
        return
      else
        shopt -s nullglob
        local pkg_dirs=("$DOTFILES_DIR"/*/)
        shopt -u nullglob
        if [[ ${#pkg_dirs[@]} -eq 0 ]]; then
          echo "No packages found."
          return
        fi
        for pkg_dir in "${pkg_dirs[@]}"; do
          echo "$(basename "$pkg_dir")"
        done
      fi
    else
      echo "Dotfiles directory not found: $DOTFILES_DIR" >&2
    fi
  fi


}

main() {
  if [[ $# -lt 1 ]]; then
    show_help
    exit 1
  fi

  local subcommand="$1"
  shift

  case "$subcommand" in
    help)
      show_help
      ;;
    init)
      init "$@"
      ;;
    add)
      add "$@"
      ;;
    remove)
      remove "$@"
      ;;
    restore)
      restore "$@"
      ;;
    list)
      list "$@"
      ;;
    *)
      echo "Unknown command: $subcommand"
      show_help
      exit 1
      ;;
  esac
}

load_config

main "$@"