#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

root="$test_tmp/root" sandbox="$test_tmp/omarchy" calls="$test_tmp/calls"
mkdir -p "$root/etc/pacman.d" "$sandbox/bin" "$sandbox/install/config" "$sandbox/default/regions" "$test_tmp/bin" "$test_tmp/home"
cp -r "$ROOT/default/regions/cn" "$sandbox/default/regions/"
mkdir -p "$sandbox/shell/Commons" && cp "$ROOT/shell/Commons/I18nZh.js" "$sandbox/shell/Commons/"
rewrite() { sed -e "s|/etc/|$root/etc/|g" -e "s| /\\.cargo/| $root/.cargo/|g" "$1" >"$2"; chmod +x "$2"; }
rewrite "$ROOT/install/config/region.sh" "$sandbox/install/config/region.sh"
rewrite "$ROOT/bin/omarchy-region" "$sandbox/bin/omarchy-region"

for command in omarchy-refresh-pacman omarchy-system-logout pacman-key pacman omarchy-apply-pacman; do
  printf '#!/bin/bash\necho "%s $*" >>"%s"\n' "$command" "$calls" >"$test_tmp/bin/$command"
done
printf '#!/bin/bash\necho "omarchy-update-pacman $*" >>"%s"\n[[ -z ${STUB_UPDATE_FAIL:-} ]]\n' "$calls" >"$test_tmp/bin/omarchy-update-pacman"
printf '#!/bin/bash\necho "${STUB_CHANNEL:-stable}"\n' >"$test_tmp/bin/omarchy-version-channel"
printf '#!/bin/bash\necho "${STUB_PLATFORM:-x86}"\n' >"$test_tmp/bin/omarchy-hw-platform"
printf '#!/bin/bash\n[[ $1 == env ]] && shift\nexec env "$@"\n' >"$test_tmp/bin/sudo"
printf '#!/bin/bash\necho "gum $*" >>"%s"\nexit "${GUM_ANSWER:-1}"\n' "$calls" >"$test_tmp/bin/gum"
chmod +x "$test_tmp/bin"/*
ln -s "$ROOT/bin/omarchy-text" "$test_tmp/bin/omarchy-text"
mkdir -p "$test_tmp/tmp"
export PATH="$test_tmp/bin:$sandbox/bin:$PATH" OMARCHY_PATH="$sandbox" HOME="$test_tmp/home" TMPDIR="$test_tmp/tmp"
switch_calls() { sed "s|$test_tmp/tmp/[^/ ]*|RENDERED|g" "$calls"; }

omarchy-region cn >/dev/null
[[ $(omarchy-region) == "China" && $(<"$root/etc/omarchy/region") == "cn" ]] ||
  fail "switching to China records cn"
[[ $(switch_calls) == $'omarchy-update-pacman -Syu --noconfirm\nomarchy-apply-pacman --render stable RENDERED\npacman --config RENDERED/pacman.conf -Sy --noconfirm --needed archlinuxcn-keyring\npacman-key --populate archlinuxcn\nomarchy-refresh-pacman stable' ]] ||
  fail "China upgrades, trusts ArchLinuxCN through the rendered cn config, then refreshes" "$(switch_calls)"
[[ -z $(ls -A "$test_tmp/tmp") ]] || fail "the rendered config is removed"
pass "switching to China trusts ArchLinuxCN before the refresh upgrades through it"

: >"$calls"
STUB_CHANNEL=edge omarchy-region cn >/dev/null
grep -qx 'omarchy-refresh-pacman edge' "$calls" || fail "the refresh keeps the machine's channel" "$(<"$calls")"
pass "switching to China again keeps the channel"

: >"$calls"
omarchy-region global >/dev/null
[[ $(omarchy-region) == "Global" && ! -e $root/etc/omarchy/region ]] ||
  fail "switching to Global removes the region"
[[ $(<"$calls") == 'omarchy-refresh-pacman stable' ]] ||
  fail "Global refreshes pacman back to the channel defaults" "$(<"$calls")"
pass "switching to Global restores the channel's pacman defaults"

if output=$(omarchy-region mars 2>&1); then
  fail "an unknown region is refused" "$output"
fi
if output=$(STUB_CHANNEL="stable / edge" omarchy-region cn 2>&1); then
  fail "a mixed channel is refused" "$output"
fi
[[ $(omarchy-region) == "Global" ]] || fail "a refused switch changes nothing"
pass "an unknown region or an unclear channel is refused"

: >"$calls"
if output=$(STUB_PLATFORM=aarch64-apple omarchy-region cn 2>&1); then
  fail "an ARM machine refuses the China region" "$output"
fi
[[ $(omarchy-region) == "Global" && ! -s $calls ]] || fail "a refused ARM switch changes nothing" "$(<"$calls")"
pass "an ARM machine refuses the China region before changing anything"

: >"$calls"
if output=$(STUB_UPDATE_FAIL=1 omarchy-region cn 2>&1); then
  fail "switching to China fails when the upgrade fails" "$output"
fi
[[ $(omarchy-region) == "Global" ]] && ! grep -q '^omarchy-refresh-pacman' "$calls" ||
  fail "a failed switch to China leaves the region Global and pacman untouched" "$(<"$calls")"
pass "a failed switch to China leaves the machine Global"

grep -q '^gum' "$calls" && fail "a switch without a terminal asks nothing" "$(<"$calls")"
: >"$calls"
output=$(LANG=zh_CN.UTF-8 GUM_ANSWER=1 script -qec "omarchy-region cn" /dev/null)
grep -qxF 'gum confirm --affirmative 立即注销 --negative 稍后 立即注销以切换开发工具镜像？' "$calls" ||
  fail "a Chinese session offers to log out in Chinese" "$(<"$calls")"
[[ $output == *"重新登录后切换开发工具镜像。"* ]] && ! grep -q '^omarchy-system-logout' "$calls" ||
  fail "declining the logout leaves a reminder and the session" "$output"
: >"$calls"
LANG=en_US.UTF-8 GUM_ANSWER=0 script -qec "omarchy-region global" /dev/null >/dev/null
grep -qxF 'gum confirm --affirmative Log out now --negative Later Log out now to switch the developer mirrors?' "$calls" &&
  grep -qx 'omarchy-system-logout ' "$calls" || fail "a terminal switch offers to log out and logs out on yes" "$(<"$calls")"
pass "a switch in a terminal offers to log out in the session's language"
