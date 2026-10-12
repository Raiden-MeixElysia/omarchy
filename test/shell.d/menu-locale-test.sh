#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command node

node - "$ROOT" <<'JS'
const fs = require('fs')
const root = process.argv[2]
const model = require(`${root}/shell/plugins/menu/MenuModel.js`)
const read = name => model.parseMenuJsonc(fs.readFileSync(`${root}/default/omarchy/${name}`, 'utf8'))
const fail = message => { console.error(`not ok - ${message}`); process.exit(1) }

const defaults = read('omarchy-menu.jsonc')
const chinese = read('omarchy-menu.zh-cn.jsonc')
const byId = Object.fromEntries(defaults.map(item => [item.id, item]))

const unknown = chinese.filter(item => !byId[item.id]).map(item => item.id)
if (unknown.length) fail(`every Chinese label names a shipped menu id: ${unknown}`)
const extra = chinese.filter(item => item.declared.some(key => key !== 'label' && key !== 'title')).map(item => item.id)
if (extra.length) fail(`the Chinese overlay only retitles rows: ${extra}`)
console.log('ok - the Chinese overlay only retitles shipped menu rows')

const user = model.parseMenuJsonc('{"system.lock": {"label": "Mine"}}')
const merged = model.mergeMenuSources(defaults, chinese.concat(user)).items
for (const item of defaults) {
  const result = merged[item.id]
  const zh = chinese.find(entry => entry.id === item.id)
  for (const key of ['action', 'when', 'checked', 'disabled', 'target', 'provider', 'kind', 'icon', 'parent']) {
    if (JSON.stringify(result[key]) !== JSON.stringify(item[key])) fail(`${item.id} keeps its ${key} under the Chinese overlay`)
  }
  if (item.id !== 'system.lock' && zh && zh.declared.includes('label') && result.label !== zh.label) fail(`${item.id} shows its Chinese label`)
}
if (merged['system.lock'].label !== 'Mine') fail('a user extension still overrides the Chinese label')
if (merged['system.reboot'].label !== '重启' || merged['setup.language'].label !== '语言' || merged['install.china.wechat'].label !== '微信') fail('Chinese labels reach the merged menu')
console.log('ok - Chinese labels replace only the label, and user extensions still win')
JS

grep -qF 'root.localeMenuItems.concat(root.userMenuItems)' "$ROOT/shell/plugins/menu/Menu.qml" &&
  grep -qF 'I18n.chinese ? omarchyPath + "/default/omarchy/omarchy-menu.zh-cn.jsonc"' "$ROOT/shell/plugins/menu/Menu.qml" &&
  grep -qF 'var chinese = Qt.locale().name.indexOf("zh_CN") === 0' "$ROOT/shell/Commons/Tr.js" ||
  fail "the menu loads the Chinese overlay under zh_CN, beneath the user extension"
pass "the menu loads the Chinese overlay under zh_CN, beneath the user extension"
