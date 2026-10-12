#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const fs = require('fs')
const vm = require('vm')

const source = fs.readFileSync(path.join(root, 'shell/Commons/I18nZh.js'), 'utf8').replace('.pragma library', '')
const context = {}
vm.runInNewContext(source + '\nthis.table = table', context)
const table = context.table

const files = []
const walk = dir => {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) walk(full)
    else if (/\.(qml|js)$/.test(entry.name)) files.push(full)
  }
}
walk(path.join(root, 'shell'))

const missing = []
let calls = 0
for (const file of files) {
  const text = fs.readFileSync(file, 'utf8')
  for (const list of text.matchAll(/I18n\.trMatch\([^\[]*\[([^\]]*)\]/g)) {
    for (const item of list[1].matchAll(/"((?:[^"\\]|\\.)*)"/g)) {
      const key = JSON.parse('"' + item[1] + '"')
      if (!(key in table)) missing.push(`${path.relative(root, file)}: ${key}`)
    }
  }
  for (const match of text.matchAll(/I18n\.tr\(\s*"((?:[^"\\]|\\.)*)"/g)) {
    calls++
    const key = JSON.parse('"' + match[1] + '"')
    if (!(key in table)) missing.push(`${path.relative(root, file)}: ${key}`)
  }
}
assert(calls > 300, 'the shell routes its text through I18n.tr', `found ${calls} calls`)

// Senders translate messages that carry a name or number with omarchy-text, or text() in Python.
const senders = []
for (const dir of ['bin', 'install/helpers', 'default/input-methods'])
for (const entry of fs.readdirSync(path.join(root, dir), { withFileTypes: true })) {
  if (!entry.isFile()) continue
  const name = path.join(dir, entry.name)
  const text = fs.readFileSync(path.join(root, name), 'utf8')
  for (const match of text.matchAll(/(?:omarchy-text\s+|\btext\(\s*)"((?:[^"\\]|\\.)*)"/g)) {
    if (match[1].includes('$')) continue
    senders.push([name, JSON.parse('"' + match[1] + '"')])
  }
}
assert(senders.length > 40, 'senders translate their parameterized messages', `found ${senders.length}`)
const unsent = senders.filter(([, key]) => !(key in table)).map(([file, key]) => `${file}: ${key}`)
assert(unsent.length === 0, 'every sender message has a Chinese entry', unsent.join('\n'))
assert(missing.length === 0, 'every I18n.tr text has a Chinese entry', missing.join('\n'))

const placeholders = s => (s.match(/%\d/g) || []).sort().join(',')
const mismatched = Object.keys(table).filter(key => placeholders(key) !== placeholders(table[key]))
assert(mismatched.length === 0, 'every Chinese entry keeps its English placeholders', mismatched.join('\n'))
JS

text=$ROOT/bin/omarchy-text
[[ $(OMARCHY_PATH=$ROOT LANG=zh_CN.UTF-8 "$text" "Sent to %1" "phone %2") == "已发送给 phone %2" ]] ||
  fail "omarchy-text translates and fills %1 in one pass"
[[ $(OMARCHY_PATH=$ROOT LANG=en_US.UTF-8 "$text" "Battery is down to %1%" 9) == "Battery is down to 9%" ]] ||
  fail "omarchy-text keeps English and a literal % outside zh_CN"
[[ $(OMARCHY_PATH=$ROOT LANG=zh_CN.UTF-8 "$text" "Unknown 50% of %1" x) == "Unknown 50% of x" ]] ||
  fail "omarchy-text passes an unknown message through"
pass "omarchy-text translates by exact key and fills arguments in one pass"
