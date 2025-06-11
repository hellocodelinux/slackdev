#!/bin/bash
set -e

BASE="/"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORKDIR="/tmp/slackdev_overlay_$TIMESTAMP"
UPPER="$WORKDIR/upper"
WORK="$WORKDIR/work"
CHROOTDIR="$WORKDIR/chroot"
USER_HOME="/home/$(whoami)"

show_help() {
  cat <<EOF
SlackDev Overlay Environment - Isolated Development Environment for Slackware
Created by Eduardo Castillo (hellocodelinux@gmail.com) - Version 1 (2025)

This script creates an isolated overlay filesystem environment perfect for:
- Testing package installations without affecting the host system
- Development work that requires system-level changes
- Experimenting with system configurations safely
- Building and testing software in a clean environment

The overlay allows you to make changes that appear real but are actually stored
in a separate layer, keeping your base Slackware system untouched.

Usage: $0 [options]
Options:
  -h, --help     Show this help and exit
  umount         Clean and unmount all overlay environments
By default, creates a new isolated overlay environment and enters it.
When exiting with 'exit', the environment is automatically unmounted.
EOF
}

cleanup() {
  echo "Cleaning up current environment..."
  
  # Unmount in reverse order
  for mnt in "$CHROOTDIR/dev/pts" "$CHROOTDIR/dev" "$CHROOTDIR/proc" "$CHROOTDIR/sys" "$CHROOTDIR/$USER_HOME"; do
    if mountpoint -q "$mnt" 2>/dev/null; then
      sudo umount "$mnt" 2>/dev/null || sudo umount -l "$mnt" 2>/dev/null || true
    fi
  done
  
  # Unmount main overlay
  if mountpoint -q "$CHROOTDIR" 2>/dev/null; then
    sudo umount "$CHROOTDIR" 2>/dev/null || sudo umount -l "$CHROOTDIR" 2>/dev/null || true
  fi
  
  echo "Current environment completely unmounted."
}

cleanup_all() {
  echo "Cleaning up all overlay environments..."
  
  # Find all slackdev overlay directories
  for overlay_dir in /tmp/slackdev_overlay_*; do
    if [ -d "$overlay_dir" ]; then
      local chrootdir="$overlay_dir/chroot"
      echo "Cleaning overlay: $overlay_dir"
      
      # Unmount in reverse order
      for mnt in "$chrootdir/dev/pts" "$chrootdir/dev" "$chrootdir/proc" "$chrootdir/sys" "$chrootdir/$USER_HOME"; do
        if mountpoint -q "$mnt" 2>/dev/null; then
          sudo umount "$mnt" 2>/dev/null || sudo umount -l "$mnt" 2>/dev/null || true
        fi
      done
      
      # Unmount main overlay
      if mountpoint -q "$chrootdir" 2>/dev/null; then
        sudo umount "$chrootdir" 2>/dev/null || sudo umount -l "$chrootdir" 2>/dev/null || true
      fi
    fi
  done
  
  echo "All overlay environments cleaned."
}

check_requirements() {
  local missing_tools=""
  
  # Check for essential tools
  if ! command -v mount >/dev/null 2>&1; then
    missing_tools="$missing_tools mount"
  fi
  
  if ! command -v umount >/dev/null 2>&1; then
    missing_tools="$missing_tools umount"
  fi
  
  if ! command -v chroot >/dev/null 2>&1; then
    missing_tools="$missing_tools chroot"
  fi
  
  if ! command -v tmux >/dev/null 2>&1; then
    missing_tools="$missing_tools tmux"
  fi
  
  # Check if overlay filesystem is supported
  if ! grep -q overlay /proc/filesystems 2>/dev/null; then
    echo "Error: OverlayFS is not supported on this kernel."
    echo "Please ensure your kernel has CONFIG_OVERLAY_FS enabled."
    exit 1
  fi
  
  if [ -n "$missing_tools" ]; then
    echo "Error: Missing required tools:$missing_tools"
    echo "Please install them using slackpkg or other package manager."
    exit 1
  fi
}

# Setup trap for automatic cleanup
trap cleanup EXIT INT TERM

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
  exit 0
fi

if [ "$1" == "umount" ]; then
  cleanup_all
  echo "If you want to manually delete the directories, run:"
  echo "  sudo rm -rf /tmp/slackdev_overlay_*"
  exit 0
fi

check_requirements

check_requirements

# Create necessary directories
mkdir -p "$UPPER" "$WORK" "$CHROOTDIR"

# Mount overlay
sudo mount -t overlay overlay -o lowerdir="$BASE",upperdir="$UPPER",workdir="$WORK" "$CHROOTDIR"

# Mount necessary filesystems
sudo mount --bind /dev "$CHROOTDIR/dev"
sudo mount --bind /dev/pts "$CHROOTDIR/dev/pts"
sudo mount --bind /proc "$CHROOTDIR/proc"
sudo mount --bind /sys "$CHROOTDIR/sys"

# Create user home directory
sudo mkdir -p "$CHROOTDIR/$USER_HOME"

# Configure bashrc
cat <<'EOF' | sudo tee "$CHROOTDIR/$USER_HOME/.bashrc" >/dev/null
export PS1='\[\e[1;32m\](slackdev)\[\e[0m\] \u@\h:\w\$ '
alias ls='ls --color=auto'
alias ll='ls -l --color=auto'
alias la='ls -la --color=auto'
EOF

# Configure profile
cat <<'EOF' | sudo tee "$CHROOTDIR/$USER_HOME/.profile" >/dev/null
echo -e "\e[1;33mYou are inside the isolated development environment (slackdev)\e[0m"
echo -e "Type 'exit' to leave the environment and return to your normal shell."
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
EOF

# Change permissions
sudo chown $(id -u):$(id -g) "$CHROOTDIR/$USER_HOME/.bashrc" "$CHROOTDIR/$USER_HOME/.profile"

# Enter the environment
echo "Creating new overlay environment: $TIMESTAMP"
echo "Environment path: $WORKDIR"

if command -v tmux >/dev/null 2>&1; then
  echo "Entering isolated environment..."
  tmux new-session -A -s "slackdev_$TIMESTAMP" "sudo chroot \"$CHROOTDIR\" /bin/bash --login" || true
else
  echo "Error: tmux is not installed. Install it to use this functionality."
  echo "You can enter manually with: sudo chroot \"$CHROOTDIR\" /bin/bash --login"
  exit 1
fi

# Cleanup will be executed automatically by the trap
