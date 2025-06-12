# SlackDev Overlay Environment

**SlackDev** is an isolated development environment for Slackware Linux. It allows you to experiment, test packages, and perform system-level development without affecting your main installation.

> ⚠️ **Important:**  
> You must run this script with `sudo` because it is required for mounting and unmounting filesystems (`mount`/`umount`).

## Features 🚀

- **Overlay Filesystem:** All changes are stored in a writable upper layer located in `/tmp/slackdev_overlay_*`, keeping your base system intact.
- **Safe Testing:** Install, remove, or modify packages and system files without risk to your main system.
- **Easy Cleanup:** When you exit the environment, all changes are automatically discarded and the overlay is removed.
- **Simple Usage:** Easy script with automatic mounting and unmounting.
- **tmux Integration:** Work comfortably inside a tmux session.

## Usage 🖥️

```bash
bash slackdev.sh [options]
```

### Options

- `-h`, `--help`: Show help and usage information.
- `umount`: Clean and unmount all active overlay environments.

By default, running the script creates a new isolated overlay environment and enters it.  
Type `exit` to leave the environment and return to your normal shell.

**Overlay path:**  
When you start a session, the overlay path is displayed, for example:  
`Overlay path: /slackdev_overlay_20250612_064333`

### Example

```bash
bash slackdev.sh
# Work inside the isolated environment...
exit
# You return to your normal shell. The overlay remains available until you unmount it.

# To clean up all overlay environments manually:
bash slackdev.sh umount
```

## Where are changes stored? 💾

All changes made inside the SlackDev environment are stored in a temporary overlay directory, typically located at `/tmp/slackdev_overlay_*`.  
This directory acts as the writable upper layer for the overlay filesystem.

**After exiting the environment, your changes are NOT deleted automatically.**  
You can find all your files and modifications in the `upper` subdirectory of the overlay path, for example:  
`/slackdev_overlay_20250612_064333/upper`

You can copy your work from there after exiting the overlay.

To remove all overlays and their data, use:
```bash
bash slackdev.sh umount
```

## Requirements 📦

- Slackware Linux
- OverlayFS support in the kernel (`CONFIG_OVERLAY_FS`)
- Tools: `mount`, `umount`, `chroot`, `tmux`
- `sudo` privileges for mounting/unmounting

## How does it work? 🛠️

The script creates a temporary overlay filesystem using `/` as the lower (read-only) layer and a writable upper layer in `/tmp/slackdev_overlay_*`. It mounts essential filesystems (`/dev`, `/proc`, `/sys`) and provides access to your home directory inside the environment.

1. Creates temporary directories in `/tmp` for the overlay upper and work layers.
2. Mounts the overlay using OverlayFS.
3. Mounts the necessary filesystems inside the environment.
4. Binds your `$HOME` directory inside the environment.
5. Starts a tmux session and enters the environment with `chroot`.
6. On exit, everything is automatically unmounted and cleaned up.

## Cleanup 🧹

To clean up all overlay environments and remove all changes:

```bash
bash slackdev.sh umount
```

To manually remove temporary overlay directories (if needed):

```bash
sudo rm -rf /slackdev_overlay_* /tmp/slackdev_overlay_*
```

## Limitations ⚠️

- Not a replacement for virtual machines or containers for advanced use cases.
- Requires sudo permissions to mount/unmount.

## Support 💬

For questions or suggestions, contact:

Eduardo Castillo (<hellocodelinux@gmail.com>)

---
