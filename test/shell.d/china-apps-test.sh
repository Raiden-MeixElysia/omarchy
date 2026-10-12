#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command node

node - "$ROOT" <<'JS'
const fs = require('fs')
const root = process.argv[2]
const model = require(`${root}/shell/plugins/menu/MenuModel.js`)
const items = model.parseMenuJsonc(fs.readFileSync(`${root}/default/omarchy/omarchy-menu.jsonc`, 'utf8'))
const china = items.filter(item => item.id === 'install.china' || item.id.startsWith('install.china.'))
const guard = '[[ "$(omarchy-region)" == "China" ]]'
const fail = message => { console.error(`not ok - ${message}`); process.exit(1) }

const aur = {
  wechat: 'wechat-universal-bwrap', qq: 'linuxqq', feishu: 'feishu-bin',
  dingtalk: 'dingtalk-bin', wemeet: 'wemeet-bin', wps: 'wps-office-cn',
}
const web = {
  'tencent-docs': ['腾讯文档', 'https://docs.qq.com'],
  yuque: ['语雀', 'https://www.yuque.com/dashboard'],
  shimo: ['石墨文档', 'https://shimo.im/desktop'],
}

if (china.length !== 1 + Object.keys(aur).length + Object.keys(web).length) fail(`China Apps has exactly the expected entries: ${china.map(i => i.id)}`)
if (!china.every(item => item.when === guard)) fail('every China Apps entry, including search hits, shows only in China')
for (const [id, pkg] of Object.entries(aur)) {
  const item = china.find(i => i.id === `install.china.${id}`)
  if (!item || item.action !== `omarchy-launch-floating-terminal-with-presentation 'omarchy-pkg-aur-add ${pkg}'` || item.disabled !== `omarchy-pkg-present ${pkg}`)
    fail(`${id} installs and checks the AUR package ${pkg}`)
}
for (const [id, [name, url]] of Object.entries(web)) {
  const item = china.find(i => i.id === `install.china.${id}`)
  if (!item || item.action !== `omarchy-launch-floating-terminal-with-presentation 'omarchy-webapp-install ${name} ${url} ""'` || item.disabled !== `[[ -f "$HOME/.local/share/applications/${name}.desktop" ]]`)
    fail(`${id} installs and checks the ${name} web app`)
}
console.log('ok - China Apps lists the AUR packages and web apps, shown only in China')
JS

aur_names="wechat-universal-bwrap linuxqq feishu-bin dingtalk-bin wemeet-bin wps-office-cn"
if [[ ${OMARCHY_TEST_NETWORK:-} == "1" ]]; then
  query=$(printf '&arg[]=%s' $aur_names)
  found=$(curl -fsSL "https://aur.archlinux.org/rpc/v5/info?${query#&}" | jq -r '.results[].Name' | sort | tr '\n' ' ')
  [[ $found == "$(printf '%s\n' $aur_names | sort | tr '\n' ' ')" ]] || fail "every China Apps package exists in the AUR" "$found"
  pass "every China Apps package exists in the AUR"
else
  skip "AUR existence check needs OMARCHY_TEST_NETWORK=1"
fi

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
mkdir -p "$test_tmp/bin" "$test_tmp/home"
cat >"$test_tmp/bin/curl" <<'SH'
#!/bin/bash
while (($#)); do [[ $1 == "-o" ]] && out=$2; shift; done
[[ -n ${out:-} ]] && printf '\x89PNG\r\n\x1a\n\0\0\0\rIHDR\0\0\0\x01\0\0\0\x01\x08\x06\0\0\0\x1f\x15\xc4\x89' >"$out"
exit 0
SH
printf '#!/bin/bash\necho "the web app wizard opened" >&2\nexit 1\n' >"$test_tmp/bin/gum"
chmod +x "$test_tmp/bin/curl" "$test_tmp/bin/gum"

grep -o "omarchy-launch-floating-terminal-with-presentation 'omarchy-webapp-install [^']*'" "$ROOT/default/omarchy/omarchy-menu.jsonc" |
  sed -e "s/^[^']*'//" -e "s/'$//" -e 's/\\"/"/g' >"$test_tmp/actions"
(($(wc -l <"$test_tmp/actions") == 3)) || fail "the menu has three China web app actions"
while read -r action; do
  HOME="$test_tmp/home" PATH="$test_tmp/bin:$ROOT/bin:$PATH" bash -c "$action" >/dev/null ||
    fail "the menu action installs its web app: $action"
done <"$test_tmp/actions"
for app in 腾讯文档 语雀 石墨文档; do
  [[ -f $test_tmp/home/.local/share/applications/$app.desktop ]] || fail "$app gets a launcher"
done
pass "each China web app action creates its launcher without the wizard"
