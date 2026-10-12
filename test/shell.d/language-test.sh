#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

root="$test_tmp/root" sandbox="$test_tmp/omarchy" calls="$test_tmp/calls"
mkdir -p "$root/etc" "$sandbox/bin" "$sandbox/shell/Commons" "$test_tmp/bin"
cp "$ROOT/shell/Commons/I18nZh.js" "$sandbox/shell/Commons/"
sed "s|/etc/|$root/etc/|g" "$ROOT/bin/omarchy-language" >"$sandbox/bin/omarchy-language"
for command in locale-gen omarchy-system-logout; do
  printf '#!/bin/bash\necho "%s $*" >>"%s"\n' "$command" "$calls" >"$test_tmp/bin/$command"
done
printf '#!/bin/bash\nexec "$@"\n' >"$test_tmp/bin/sudo"
printf '#!/bin/bash\necho "gum $*" >>"%s"\nexit "${GUM_ANSWER:-1}"\n' "$calls" >"$test_tmp/bin/gum"
chmod +x "$test_tmp/bin"/* "$sandbox/bin/omarchy-language"
ln -s "$ROOT/bin/omarchy-text" "$test_tmp/bin/omarchy-text"
export PATH="$test_tmp/bin:$sandbox/bin:$PATH" OMARCHY_PATH="$sandbox" LANG=en_US.UTF-8

printf '#zh_CN.UTF-8 UTF-8\nen_US.UTF-8 UTF-8\n' >"$root/etc/locale.gen"
printf 'LANG=en_US.UTF-8\nLC_TIME=en_DK.UTF-8\n' >"$root/etc/locale.conf"

[[ $(omarchy-language) == "en_US.UTF-8" ]] || fail "omarchy-language prints the system LANG"
pass "omarchy-language prints the system LANG"

: >"$calls"
output=$(omarchy-language zh)
[[ $(<"$root/etc/locale.gen") == $'zh_CN.UTF-8 UTF-8\nen_US.UTF-8 UTF-8' ]] || fail "Chinese enables zh_CN in locale.gen"
[[ $(<"$root/etc/locale.conf") == $'LANG=zh_CN.UTF-8\nLC_TIME=en_DK.UTF-8' ]] || fail "Chinese sets LANG and keeps other settings" "$(<"$root/etc/locale.conf")"
[[ $(<"$calls") == "locale-gen " ]] || fail "Chinese generates the locale and asks nothing without a terminal" "$(<"$calls")"
[[ $output == "重新登录后切换语言。" ]] || fail "Chinese reminds to log back in, in Chinese" "$output"
pass "switching to Chinese generates zh_CN, sets LANG, and reminds in Chinese"

sed -i 's/^en_US/#en_US/' "$root/etc/locale.gen"
output=$(omarchy-language en)
[[ $(<"$root/etc/locale.gen") == $'zh_CN.UTF-8 UTF-8\nen_US.UTF-8 UTF-8' ]] || fail "English enables en_US in locale.gen"
[[ $(<"$root/etc/locale.conf") == $'LANG=en_US.UTF-8\nLC_TIME=en_DK.UTF-8' ]] || fail "English sets LANG back" "$(<"$root/etc/locale.conf")"
[[ $output == "Log back in to switch the language." ]] || fail "English reminds in English" "$output"
pass "switching to English generates en_US and sets LANG"

printf 'LC_TIME=en_DK.UTF-8' >"$root/etc/locale.conf"
omarchy-language zh >/dev/null
[[ $(<"$root/etc/locale.conf") == $'LC_TIME=en_DK.UTF-8\nLANG=zh_CN.UTF-8' ]] || fail "a locale.conf without LANG or a final newline gains LANG on its own line" "$(<"$root/etc/locale.conf")"
: >"$root/etc/locale.conf"
omarchy-language en >/dev/null
[[ $(<"$root/etc/locale.conf") == "LANG=en_US.UTF-8" ]] || fail "an empty locale.conf gains LANG" "$(<"$root/etc/locale.conf")"
pass "a locale.conf without LANG gains one on its own line"

printf 'LANG="zh_CN.UTF-8"\n' >"$root/etc/locale.conf"
[[ $(omarchy-language) == "zh_CN.UTF-8" ]] || fail "a double-quoted LANG reads unquoted" "$(omarchy-language)"
printf "LANG='en_US.UTF-8'\n" >"$root/etc/locale.conf"
[[ $(omarchy-language) == "en_US.UTF-8" ]] || fail "a single-quoted LANG reads unquoted" "$(omarchy-language)"
printf 'LC_TIME=en_DK.UTF-8\n' >"$root/etc/locale.conf"
[[ -z $(LANG=de_DE.UTF-8 omarchy-language) ]] || fail "a locale.conf without LANG reads empty, not the caller's LANG"
pass "omarchy-language reads quoted values and ignores the caller's LANG"

before=$(<"$root/etc/locale.conf")
if output=$(omarchy-language fr 2>&1); then
  fail "an unknown language is refused" "$output"
fi
[[ $output == "Usage: omarchy-language [en|zh]" && $(<"$root/etc/locale.conf") == "$before" ]] || fail "a refused language changes nothing" "$output"
pass "an unknown language is refused and changes nothing"

: >"$calls"
GUM_ANSWER=0 script -qec "omarchy-language en" /dev/null >/dev/null
grep -qxF 'gum confirm --affirmative Log out now --negative Later Log out now to switch the language?' "$calls" &&
  grep -qx 'omarchy-system-logout ' "$calls" || fail "a terminal switch offers to log out and logs out on yes" "$(<"$calls")"
: >"$calls"
GUM_ANSWER=1 script -qec "omarchy-language zh" /dev/null >/dev/null
grep -qxF 'gum confirm --affirmative 立即注销 --negative 稍后 立即注销以切换语言？' "$calls" && ! grep -q '^omarchy-system-logout' "$calls" ||
  fail "a terminal switch asks in the new language and keeps the session on no" "$(<"$calls")"
pass "a terminal switch offers to log out in the new language"
