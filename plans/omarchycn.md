# OmarchyCN task list

Progress source of truth for the `omarchycn` branches of `omarchy`, `omarchy-iso` and `omarchy-pkgs`. Work top to bottom, one item at a time. Each item closes only after a codex review (GPT 6.1 Sol, xhigh, in a herdr split) passes; at most 5 reviews per item.

## Decisions (confirmed with the owner, 2026-10-05)

- Region is machine state in `/etc/omarchy/region` (`china`); absent means Global.
- Arch and Omarchy repos follow the domain plan: every `*.omarchy.org` server gets a `*.omarchy.cn` twin listed first. `pkgs.omarchy.cn` is live; `stable-mirror`, `rc-mirror` and `mirror.omarchy.cn` do not resolve yet, so pacman falls through to `.org`.
- China means a Chinese UI: `LANG=zh_CN.UTF-8` and Chinese menu labels. Global means `en_US.UTF-8`. `omarchy update` never touches the locale.
- Input method: rime-ice-installer (omarchy-pkgs PR 265, not merged yet). The ISO bundles the package, the Rime Ice `full.zip` and the Wanxiang grammar model; the install finishes with Rime and US keyboard ready, Ctrl+Space toggles. The installer gets a local patch: `--asset-dir` and no sudo when its packages are present.
- China to Global: switch sources and language, keep CJK fonts and the input method, remove the Claude Code third-party provider entry and the env it wrote, hide the China software entry. Dim and Kimi stay for every region.
- Deferred provisioning and factory reset get the region's system setup but no offline input method (deferred).

## Decisions (owner and maintainers, 2026-10-08)

These replace the 2026-10-05 decisions where they disagree.

- Region and language are separate. Region comes from the timezone the user picks (omarchy #13690, omarchy-iso #241); the installer adds no region screen. Language is the first installer screen.
- The `.cn` pacman mirrors are #13690's `mirrorlist-<channel>.prepend` files. Our `servers.sed` twins and the USTC Arch fallback go; `[omarchy]` keeps only `pkgs.omarchy.org`, as in #13690.
- Input methods come from dhh's #14433 and omarchy-iso #237. Rime, `rime-ice-installer` and its bundled assets go.
- The language picker offers English and Simplified Chinese. Chinese reruns the installer in cage + foot with fonts unpacked from the offline repository's `noto-fonts-cjk`; the target gets `LANG=zh_CN.UTF-8`.
- Setup > Region switches mirrors, developer mirrors, the China apps entry and the Claude Code API entry. Setup > Language switches `LANG` and the Chinese UI. Neither touches the other.

## Decisions (owner, 2026-10-11, after the maintainers tested the ISO)

- Drop _Setup > Claude Code API_ (`omarchy-setup-claude-api`) and the Dim/Kimi agent roster and migration. `omarchy region global` no longer touches Claude settings.
- Drop the ISO's local-build pin (`pin_local_packages`, `IgnorePkg` and its hooks).
- Drop the `omarchy-pkg-add` change; it served Rime.
- PRs carry only our changes and never overlap Yunjie Dai's (#13690, iso #241) or David's (#14433, iso #237). Region work stacks on #13690; ISO work stacks on iso #241.

## Shipping prerequisites

- The region profile and timezone mapping wait on omarchy #13690 and omarchy-iso #241; input methods (omarchy #14433, omarchy-iso #237) are merged. The language screen, CJK console, Chinese UI, developer mirrors and China apps exist only on the `omarchycn` branches: build a test ISO with `./bin/omarchy-iso-make --local-source ../omarchy ../omarchy-pkgs` from `omarchy-iso/`.
- A local-source ISO builds `omarchy-dev` and `omarchy-settings-dev` under the published version number and does not pin them, so the next published release replaces them on `omarchy update`. Local test ISOs are for testing only.
- `stable-mirror.omarchy.cn`, `rc-mirror.omarchy.cn` and `mirror.omarchy.cn` resolve and serve `core.db` (checked 2026-10-09).

## PR branches (T32, 2026-10-12)

omarchy, each a fork branch:

- `cjk-variant-selection` on upstream `quattro`: the Noto CJK variant fontconfig.
- `chinese-language` on upstream `quattro`: `omarchy language`, Setup > Language, the installer's language prompt, the Chinese menu overlay, shell and notification text.
- `cn-developer-mirrors` on #13690: the `cn` developer mirrors at install.
- `cn-region-switch` on `cn-developer-mirrors`: `omarchy region`, Setup > Region, China Apps, `manual/52-china.md`; English only.

`omarchycn` merges them onto `quattro` and adds what no PR can carry yet: the Chinese wording for Region and China Apps and the language half of the China manual (needs both language and region), and an integration-only pacman resolution until #13690 rebases onto upstream's ARM templates. Known failure there: `pacman-templates-test` expects x86 refresh to copy templates directly, which #13690 replaces with a render.

## Tasks

- [x] T0 Branches and this list
- [x] T1 China package sources (PRD 1): region state, `omarchy-region` reader, `default/region/china/pacman.sed`, applied by `omarchy-refresh-pacman` and `install/post-install/pacman.sh`; tests
- [x] T2 Region choice in the installer (PRD 2): `omarchy_prompt_region` in `setup-form.sh`, ISO configurator screen, orchestrator passes `OMARCHY_REGION`, `install/config/region.sh` records it
- [x] T3 Input method (PRD 3): rime-ice-installer patch and PKGBUILD in omarchy-pkgs, IME packages in `omarchy-other.packages`, install-time package add, user step runs the installer from bundled assets, ISO build bundles assets and the package
- [x] T4 CJK fontconfig fix (PRD 4): rebuild PR 9693 on the current base
- [x] T5 AI (PRD 5): Dim and Kimi Code for every region (rebuild PR 9694), Claude Code third-party provider setup shown only in China
- [x] T6 Developer mirrors (PRD 6): npm, PyPI/uv, Go, rustup, crates.io, RubyGems, Maven via system drop-ins under `default/region/china/`
- [x] T7 China software (PRD 7): Install menu entry shown only in China
- [x] T8 Region switching and Chinese UI (PRD 8): `omarchy-region china|global`, Setup > Region, locale, Chinese menu overlay chosen by `LANG`
- [x] T9 Logo (PRD 9): stock Omarchy logo everywhere
- [x] T10 Docs: `AGENTS.md`, manual
- [x] T11 Test ISO build (local source)
- [x] T12 QEMU install and verification: China and Global installs, region switch, `omarchy update` keeps region and language
- [x] T13 Acceptance checklist
- [x] T14 Chinese installer (owner request, parity with the old OmarchyCN ISO): choosing China on the VT reruns the installer in cage + foot with CJK fonts and a US keyboard, falling back to the English VT; there the region screen is bilingual and Global returns to the VT; every later installer screen, the shared setup form and the install dashboard read in Chinese
- [x] T15 Global to China fails on local-source installs (owner report): `rime-ice-installer` lives only in the ISO's offline mirror, so a Global install cannot fetch it later; local-source installs install every pinned local build, and `install/config/region.sh` installs the China packages before it writes any region state
- [x] T16 A region switch offers to log out at once, since the language and the developer mirrors only reach a new session (owner request)
- [x] T17 The desktop shell reads in Chinese under `zh_CN` (owner report): notifications, the bar panels (agents, network, display and the rest), the menu's search prompt — review cap reached: five codex rounds; the round-5 findings (user text translated at display, custom reminder list lines, reminder tooltips and errors) are fixed by wording every notification at its sender and verified by tests and in the China VM, without a sixth review
- [x] T18 Merge the official region-profile PRs (omarchy #13690, #14399; omarchy-iso #206, #236) and align to them: region code `cn` in `/etc/omarchy/region`, China files under `default/regions/cn/`, pacman rendered by `omarchy-apply-pacman` (`.cn` twins first, USTC fallback, ArchLinuxCN with its keyring), offline timezone `Asia/Shanghai`; the ISO keeps the first-screen region choice and bundles the China profile, `--region cn` preselects China

- [x] T19 Merge the reworked #13690 (timezone-derived region) and align: `mirrorlist-<channel>.prepend` and `timezones` replace `servers.sed`, `mirrorlist.append` and `timezone`; drop #14399's timezone preselection (closed upstream); `install/config/region.sh` reads `/etc/omarchy/region` instead of `OMARCHY_REGION`; drop the dead `china` rename migration
- [x] T20 Merge #14433 (input methods) and remove Rime: packages, `install/user/region.sh`, the Rime steps in `install/config/region.sh` and `omarchy-region`
- [x] T21 Split language from region: `omarchy-language en|zh` and Setup > Language own `LANG`; `omarchy-region` and `install/config/region.sh` stop touching the locale
- [x] T22 omarchy-pkgs: revert the `rime-ice-installer` package
- [x] T23 omarchy-iso: merge upstream `quattro` (#237) and #241; remove `--region`, `prepare-region.sh`, the region skel, the region preselected timezone, Rime bundling and its pin
- [x] T24 omarchy-iso: the language screen replaces the region screen; Chinese reruns in cage + foot with `noto-fonts-cjk` unpacked from the offline repository (no font packages added to the ISO); the CJK console lists only US-keymap keyboards and preselects Chinese (Simplified, Pinyin); the target gets `zh_CN.UTF-8` through `locale_config`; the harness takes `--language zh`
- [x] T25 Docs: `AGENTS.md`, `docs/regions.md`, `manual/52-china.md`, omarchy-iso README
- [x] T26 Build the local-source ISO and test in QEMU: Chinese + `Asia/Shanghai`, English + `America/New_York`, runtime region and language switches
- [x] T27 Acceptance checklist for T19–T26

- [x] T28 Drop the Claude Code API setup, the Dim/Kimi roster and migration, and the `omarchy-pkg-add` change (omarchy)
- [x] T29 Drop `pin_local_packages` and the pin list (omarchy-iso)
- [x] T30 The CJK console skips the second language screen; the summary's keyboard row shows the chosen layout, not its keymap (omarchy-iso)
- [x] T31 The CJK console fills the screen and the summary keeps the logo in view (omarchy-iso)
- [ ] T32 Rebuild omarchy as PR branches on current upstream: CJK fontconfig, language and menus, shell text, cn developer mirrors (on #13690), Setup > Region and China Apps; `omarchycn` becomes their merge
- [ ] T33 Rebuild omarchy-iso as one PR branch on iso #241 and current upstream; `omarchycn` becomes it; omarchy-pkgs follows upstream master
- [ ] T34 Build the local-source ISO and test in QEMU: Chinese offline, English
- [ ] T35 Acceptance checklist for T28–T34
- [ ] T36 Open the PRs one at a time from Raiden-MeixElysia

## Acceptance checklist

Evidence comes from the T26 runs of `omarchy-iso/release/omarchy-2026.10.09-x86_64-local.iso` (omarchy fcd681c0, omarchy-iso 30f63b6, omarchy-pkgs a4cc3234): run A in host QEMU with the guest cut off from the network during install, run B in the ISO test harness.

| # | Requirement (discussion of 2026-10-08) | Result | Evidence |
|---|---|---|---|
| 1 | Language picker on the first screen; Chinese gets cage + foot | Pass | Run A: the VT screen offers English and Chinese; Chinese reruns in cage + foot on a bilingual language screen, and every later screen and the install dashboard read in Chinese. |
| 2 | CJK font from the offline repository, not added to the ISO | Pass | `unpack_cjk_font` extracts `NotoSansCJK-Regular.ttc` from the offline mirror's `noto-fonts-cjk`; the ISO package list drops `ttf-jetbrains-mono` and `wqy-microhei` and keeps only `cage` and `foot`. |
| 3 | Translated installer strings and the target locale | Pass | Run A: summary, finish screen and dashboard in Chinese; installed `LANG=zh_CN.UTF-8` through `locale_config`. Run B: English throughout, `LANG=en_US.UTF-8`. |
| 4 | Region from the timezone, no extra step (#13690, #241) | Pass | Run A: `Asia/Shanghai` shows 区域 cn on the summary and writes `/etc/omarchy/region` = `cn`. Run B: `America/New_York` installs Global with no marker. |
| 5 | Offline install ready without network | Pass | Run A installed in 8m13s with the guest network cut off; ArchLinuxCN keyring trusted, `mirror.omarchy.cn` first, Pinyin ready at first login. |
| 6 | `.cn` pacman mirrors from #13690; ours dropped | Pass | China: `mirror.omarchy.cn` before `mirror.omarchy.org`, `[archlinuxcn]` from USTC. Global: mirrorlist equals the channel template; `pacman.conf` differs only by the local-build `IgnorePkg` pin. |
| 7 | Developer mirrors on the cn profile | Pass | China links `/etc/environment.d/90-omarchy-china.conf`, `/.cargo/config.toml`, `/etc/gemrc`; Global removes them and `NPM_CONFIG_REGISTRY` is gone after relogin. |
| 8 | Input methods from dhh's #14433; Rime removed | Pass | Chinese preselects Chinese (Simplified, Pinyin); `INPUT_METHOD=pinyin`; `Ctrl + Shift + Space` then `nihao` typed 你好. No Rime package, asset or pin remains. |
| 9 | Region and language switch separately at runtime | Pass | `omarchy region global` and `cn` leave `LANG` alone; `omarchy language en` and `zh` leave the region alone; each offers logout in the right language; Claude Code API and China Apps follow the region. |
| 10 | `omarchy update` keeps region and language | Pass | After `omarchy update -y`: `LANG=zh_CN.UTF-8`, region `cn`, `mirror.omarchy.cn` first, `[archlinuxcn]` present. |
| - | Automated tests | Pass, no new regressions | omarchy shell suite in an Arch container: every failure is environmental and predates these tasks; some sit in branch-only tests (`fontconfig-cjk-test` needs the Omarchy font set, `hyprland-jis-bindings-test` needs `lua`, `menu-plugin-test` and `tailscale-receive-test` chmod a symlink on the read-only mount). omarchy-iso `./test/all` passes apart from `test_keyboard` (needs systemd's `localectl`). Harness acceptance: four failures outside this branch (Mozc Qt; weather and reminder prompts on screen but missed by OCR; `linux-omarchy` vs `omarchy-bore` kernel). |

Open items outside this branch: the shipping prerequisites above; the four acceptance failures listed; `.automated_script.sh` exits 1 when its dashboard returns without rebooting after the mirror warm-up has finished, from upstream's `EXIT` trap under `set -e`; each `omarchy region` switch asks for the sudo password several times through refresh's command-scoped `sudo` calls.
