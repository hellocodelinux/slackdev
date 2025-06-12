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
Created by Eduardo Castillo (hellocodelinux@gmail.com) - Version 1.1 (2025)

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

IMPORTANT: Run this script as root (or with sudo: sudo $0 ...)
EOF
}

cleanup() {
  echo "Cleaning up current environment..."
  
  # Unmount in reverse order
  for mnt in "$CHROOTDIR/dev/pts" "$CHROOTDIR/dev" "$CHROOTDIR/proc" "$CHROOTDIR/sys" "$CHROOTDIR/$USER_HOME"; do
    if mountpoint -q "$mnt" 2>/dev/null; then
      umount "$mnt" 2>/dev/null || umount -l "$mnt" 2>/dev/null || true
    fi
  done
  
  # Unmount main overlay
  if mountpoint -q "$CHROOTDIR" 2>/dev/null; then
    umount "$CHROOTDIR" 2>/dev/null || umount -l "$chrootdir" 2>/dev/null || true
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
          umount "$mnt" 2>/dev/null || umount -l "$mnt" 2>/dev/null || true
        fi
      done
      
      # Unmount main overlay
      if mountpoint -q "$chrootdir" 2>/dev/null; then
        umount "$chrootdir" 2>/dev/null || umount -l "$chrootdir" 2>/dev/null || true
      fi
    fi
  done
  
  echo "All overlay environments cleaned."
}

check_requirements() {
  local missing_tools=""
  
  # Check for essential tools
  for tool in mount umount chroot tmux; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing_tools="$missing_tools $tool"
    fi
  done
  
  # Try to load overlay module if not present
  if ! grep -q overlay /proc/filesystems 2>/dev/null; then
    if command -v modprobe >/dev/null 2>&1; then
      echo "OverlayFS module not loaded, trying to load it..."
      modprobe overlay 2>/dev/null || true
    fi
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

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Try: sudo $0 ..."
  exit 1
fi

check_requirements

# Create necessary directories
mkdir -p "$UPPER" "$WORK" "$CHROOTDIR"

# Mount overlay
mount -t overlay overlay -o lowerdir="$BASE",upperdir="$UPPER",workdir="$WORK" "$CHROOTDIR"

# Mount necessary filesystems
mount --bind /dev "$CHROOTDIR/dev"
mount --bind /dev/pts "$CHROOTDIR/dev/pts"
mount --bind /proc "$CHROOTDIR/proc"
mount --bind /sys "$CHROOTDIR/sys"

# Create user home directory
mkdir -p "$CHROOTDIR/$USER_HOME"

# Copy essential files to chroot if they don't exist
for file in passwd group shadow; do
  if [ ! -f "$CHROOTDIR/etc/$file" ] && [ -f "/etc/$file" ]; then
    cp "/etc/$file" "$CHROOTDIR/etc/$file"
  fi
done

# Create user inside chroot if it doesn't exist
CHROOT_USER=$(whoami)
CHROOT_UID=$(id -u)
CHROOT_GID=$(id -g)
if ! grep -q "^$CHROOT_USER:" "$CHROOTDIR/etc/passwd" 2>/dev/null; then
  echo "$CHROOT_USER:x:$CHROOT_UID:$CHROOT_GID::${USER_HOME}:/bin/bash" >> "$CHROOTDIR/etc/passwd"
fi
if ! grep -q "^$CHROOT_USER:" "$CHROOTDIR/etc/group" 2>/dev/null; then
  echo "$CHROOT_USER:x:$CHROOT_GID:" >> "$CHROOTDIR/etc/group"
fi

# Change ownership of home and files to user inside chroot
chown -R "$CHROOT_UID:$CHROOT_GID" "$CHROOTDIR/$USER_HOME"

# Enter the environment
echo "Creating new overlay environment: $TIMESTAMP"
echo "Environment path: $WORKDIR"

# Create a clean environment script
SLACKDEV_INIT_SCRIPT="$CHROOTDIR/tmp/slackdev_init.sh"
cat > "$SLACKDEV_INIT_SCRIPT" << 'EOF'
#!/bin/bash

# Set clean environment
export SHELL=/bin/bash
export TERM=${TERM:-xterm}
export LANG=${LANG:-C}
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Welcome message
echo -e "\e[1;33mYou are inside the isolated development environment (slackdev)\e[0m"
echo -e ""
echo -e "Type 'exit' to leave the environment and return to your normal shell."
echo -e "Overlay path: OVERLAY_PATH_PLACEHOLDER"
echo -e ""
echo -e "All changes and files created in this environment are stored in:"
echo -e "  UPPER_PATH_PLACEHOLDER"
echo -e "You can copy your work from there after exiting the overlay."
echo -e ""

# Start interactive bash session with custom bashrc
exec /bin/bash --rcfile /tmp/.slackdev_bashrc -i
EOF

# Replace placeholders in the init script
sed -i "s|OVERLAY_PATH_PLACEHOLDER|$WORKDIR|g" "$SLACKDEV_INIT_SCRIPT"
sed -i "s|UPPER_PATH_PLACEHOLDER|$UPPER|g" "$SLACKDEV_INIT_SCRIPT"
chmod +x "$SLACKDEV_INIT_SCRIPT"

# Create custom bashrc for slackdev environment
cat > "$CHROOTDIR/tmp/.slackdev_bashrc" << 'BASHRC_EOF'
# SlackDev custom bashrc configuration

# Set the custom prompt
export PS1="\[\e[1;32m\](slackdev)\[\e[0m\] \u@\h:\w\$ "

# History search bindings
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Color aliases
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Convenience aliases
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'

# Bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

cd /root
BASHRC_EOF

if command -v tmux >/dev/null 2>&1; then
  echo "Entering isolated environment..."
  tmux new-session -A -s "slackdev_$TIMESTAMP" "chroot \"$CHROOTDIR\" /tmp/slackdev_init.sh" || true
else
  echo "Error: tmux is not installed. Install it to use this functionality."
  echo "You can enter manually with: chroot \"$CHROOTDIR\" /tmp/slackdev_init.sh"
  exit 1
fi

# Clean up the init script and temporary bashrc
rm -f "$SLACKDEV_INIT_SCRIPT"
rm -f "$CHROOTDIR/tmp/.slackdev_bashrc"

# Cleanup will be executed automatically by the trap
