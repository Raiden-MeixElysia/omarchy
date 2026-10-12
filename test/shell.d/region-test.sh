#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

region_setup="$test_tmp/region.sh"
root="$test_tmp/root"
sed -e "s|/etc/|$root/etc/|g" -e "s| /\.cargo/| $root/.cargo/|g" "$ROOT/install/config/region.sh" >"$region_setup"
export OMARCHY_PATH="$ROOT"
mkdir -p "$root/etc/omarchy"

bash -e "$region_setup"
[[ -z $(find "$root" -type l) ]] || fail "no marker links nothing"
pass "no marker installs Global"

echo cn >"$root/etc/omarchy/region"
bash -e "$region_setup"
for link in "environment.conf etc/environment.d/90-omarchy-china.conf" "cargo.toml .cargo/config.toml" "gemrc etc/gemrc"; do
  read -r source target <<<"$link"
  [[ $(readlink "$root/$target") == "$ROOT/default/regions/cn/$source" ]] || fail "China links /$target to the shipped $source"
done
bash -e "$region_setup"
pass "the cn marker links the developer mirror drop-ins, again without error"

rm "$root/etc/gemrc"
echo ":sources: []" >"$root/etc/gemrc"
if output=$(bash -e "$region_setup" 2>&1); then
  fail "China refuses to replace an admin's /etc/gemrc" "$output"
fi
[[ $output == "Refusing to replace $root/etc/gemrc, which Omarchy did not create" && $(<"$root/etc/gemrc") == ":sources: []" ]] ||
  fail "China names the file it refuses to replace and leaves it" "$output"
rm "$root/etc/gemrc"
pass "region setup never replaces mirror config Omarchy did not create"

echo mars >"$root/etc/omarchy/region"
if output=$(bash -e "$region_setup" 2>&1); then
  fail "an unknown region fails" "$output"
fi
[[ $output == "Unknown region: mars" ]] || fail "region setup names the unknown region" "$output"
pass "region setup rejects an unknown region"

echo cn >"$root/etc/omarchy/region"
bash -e "$region_setup"
OMARCHY_REGION=global bash -e "$region_setup"
[[ ! -e $root/etc/omarchy/region && -z $(find "$root" -type l) ]] || fail "Global removes the marker and the developer mirror links"
ln -s /usr/share/somewhere/gemrc "$root/etc/gemrc"
OMARCHY_REGION=global bash -e "$region_setup"
[[ -L $root/etc/gemrc ]] || fail "Global keeps a gemrc link Omarchy did not create"
rm "$root/etc/gemrc"
pass "switching to Global removes only what Omarchy linked"

OMARCHY_REGION=cn bash -e "$region_setup"
[[ $(<"$root/etc/omarchy/region") == "cn" && $(readlink "$root/etc/gemrc") == "$ROOT/default/regions/cn/gemrc" ]] ||
  fail "switching to China records cn and links the drop-ins"
pass "switching to China records cn and links the drop-ins"

region_bin="$test_tmp/omarchy-region"
sed "s|/etc/omarchy/region|$root/etc/omarchy/region|" "$ROOT/bin/omarchy-region" >"$region_bin"
chmod +x "$region_bin"
[[ $("$region_bin") == "China" ]] || fail "the cn marker reads as China"
rm "$root/etc/omarchy/region"
[[ $("$region_bin") == "Global" ]] || fail "no marker reads as Global"
echo mars >"$root/etc/omarchy/region"
if output=$("$region_bin" 2>&1); then
  fail "an unknown marker fails" "$output"
fi
[[ $output == "Unknown region in $root/etc/omarchy/region: mars" ]] || fail "the reader names the file and value" "$output"
pass "omarchy region reads Global, China, and fails on anything else"

grep -qx 'run_logged "$OMARCHY_INSTALL/config/region.sh"' "$ROOT/install/config/all.sh" || fail "the install runs region setup"
pass "the install runs region setup"
