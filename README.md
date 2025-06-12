# SlackDev Overlay Environment

**SlackDev** is an isolated development environment for Slackware Linux. It allows you to experiment, test packages, and perform system-level development without affecting your main installation.

## Features

- **Overlay Filesystem:** All changes are stored in a separate layer, keeping your base system intact.
- **Safe Testing:** Install, remove, or modify packages and system files without risk.
- **Easy Cleanup:** When you exit the environment, all changes are automatically discarded.
- **Simple Usage:** Easy script with automatic mounting and unmounting.
- **tmux Integration:** Work comfortably inside a tmux session.

## Usage

```bash
bash slackdev.sh [options]
```

### Options

- `-h`, `--help`: Show help and usage information.
- `umount`: Clean and unmount all active overlay environments.

By default, running the script creates a new isolated overlay environment and enters it. When you exit (`exit`), the environment is automatically unmounted.

### Example

```bash
bash slackdev.sh
# Work inside the isolated environment...
exit
# The environment is unmounted and all changes are cleaned up.

# To clean up all overlay environments manually:
bash slackdev.sh umount
```

## Requirements

- Slackware Linux
- OverlayFS support in the kernel (`CONFIG_OVERLAY_FS`)
- Tools: `mount`, `umount`, `chroot`, `tmux`

## How does it work?

The script creates a temporary overlay filesystem using `/` as the lower layer and a writable upper layer in `/tmp`. It mounts essential filesystems (`/dev`, `/proc`, `/sys`) and provides access to your home directory inside the environment.

1. Creates temporary directories in `/tmp`.
2. Mounts the overlay using OverlayFS.
3. Mounts the necessary filesystems inside the environment.
4. Provides your `$HOME` inside the environment.
5. Starts a tmux session and enters the environment with `chroot`.
6. On exit, everything is automatically unmounted and cleaned up.

## Cleanup

To clean up all overlay environments:

```bash
bash slackdev.sh umount
```

To manually remove temporary overlay directories:

```bash
sudo rm -rf /tmp/slackdev_overlay_*
```

## Limitations

- Changes are not persistent after leaving the environment.
- Not a replacement for virtual machines or containers for advanced use cases.
- Requires sudo permissions to mount/unmount.

## Support

For questions or suggestions, contact:

Eduardo Castillo (<hellocodelinux@gmail.com>)

---
