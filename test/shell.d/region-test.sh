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

grep -qx 'run_logged "$OMARCHY_INSTALL/config/region.sh"' "$ROOT/install/config/all.sh" || fail "the install runs region setup"
pass "the install runs region setup"
