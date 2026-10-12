# China

Omarchy works in mainland China without a VPN. The timezone you pick in the installer decides the region: `Asia/Shanghai`, `Asia/Urumqi` and their older names select China; any other timezone is Global. The summary screen shows _Region: cn_ before anything touches the disk.

## What the China region sets up

| Area | China | Global |
|------|-------|--------|
| Arch packages | The channel's `.omarchy.cn` mirror first, its `.omarchy.org` mirror behind it, and the ArchLinuxCN repository with its keyring | `.omarchy.org` mirrors |
| Omarchy packages | `pkgs.omarchy.org` | `pkgs.omarchy.org` |
| Developer mirrors | npm, PyPI and uv, Go, rustup and crates.io, RubyGems and Bundler, Maven | Upstream registries |
| Software | _Install > China Apps_ | Hidden |

pacman tries the `.cn` mirror first. If it is unreachable or lacks a package, pacman falls through to `.org`, which works for anyone with their own VPN. The installer carries the China packages on the ISO, so a China install needs no network.

## Developer mirrors

China machines point the common package managers at mirrors inside China. Environment variables in `/etc/environment.d/90-omarchy-china.conf` cover npm, PyPI and uv, Go, rustup, Bundler and Maven; they reach everything started from the desktop after your next login (not SSH or TTY shells), and they take precedence over npm, pip, uv and Go config files, so unset the variable in a shell to opt out. `/.cargo/config.toml` points crates.io at the mirror unless a project's `.cargo/config.toml` says otherwise, and `/etc/gemrc` sets the RubyGems source unless your `~/.gemrc` sets another. Omarchy never replaces one of those two files if it is a regular file you created. Toolchain downloads by mise, such as Node.js or Go themselves, still come from upstream.

## China Apps

_Install > China Apps_ installs WeChat, QQ, Feishu, DingTalk, Tencent Meeting and WPS Office from the AUR, and sets up Tencent Docs, Yuque and Shimo as web apps.

## Switching later

_Setup > Region_, or `omarchy region cn` and `omarchy region global`, switches the region. China runs a full system update, trusts the ArchLinuxCN keyring, records the region, moves pacman to the `.cn` mirrors and links the developer mirrors. Global moves pacman back to `.org`, removes the developer mirrors and hides _Install > China Apps_; apps you installed from it stay. The developer mirrors change at the next login, so the switch offers to log out. `omarchy update` never changes the region.

A machine prepared for another owner installs Global, since its timezone is only set on first boot. Switch it under _Setup > Region_ once it is online.
