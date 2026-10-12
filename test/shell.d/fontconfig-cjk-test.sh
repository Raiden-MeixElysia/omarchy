#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

if ! command -v fc-match >/dev/null || [[ $(fc-list : file) != *NotoSansCJK-Regular.ttc* ]]; then
  skip "fontconfig CJK variants need fc-match and noto-fonts-cjk"
  exit 0
fi

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

candidate="$ROOT/default/fontconfig/conf.avail/50-omarchy.conf"
{
  echo '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig>'
  echo "<dir>/usr/share/fonts</dir><cachedir>$test_tmp/cache</cachedir>"
  placed=false
  for conf in /etc/fonts/conf.d/*.conf; do
    name=${conf##*/}
    [[ $name == "50-omarchy.conf" ]] && continue
    if ! $placed && [[ $name > "50-omarchy.conf" ]]; then
      echo "<include>$candidate</include>"
      placed=true
    fi
    echo "<include>$conf</include>"
  done
  $placed || echo "<include>$candidate</include>"
  echo '</fontconfig>'
} >"$test_tmp/fonts.conf"
export FONTCONFIG_FILE="$test_tmp/fonts.conf"
fc-cache >/dev/null

# Pango, Qt and Skia add lang as a string, which fc-match never does.
cat >"$test_tmp/string-lang.py" <<'PY'
import ctypes, sys
fc = ctypes.CDLL("libfontconfig.so.1")
fc.FcPatternCreate.restype = ctypes.c_void_p
fc.FcPatternAddString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
fc.FcConfigSubstitute.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]
fc.FcDefaultSubstitute.argtypes = [ctypes.c_void_p]
fc.FcPatternFormat.restype = ctypes.c_char_p
fc.FcPatternFormat.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
fc.FcCharSetCreate.restype = ctypes.c_void_p
fc.FcCharSetAddChar.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
fc.FcPatternAddCharSet.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_void_p]
fc.FcFontMatch.restype = ctypes.c_void_p
fc.FcFontMatch.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_int)]
for line in sys.stdin:
  family, lang, char = line.split()
  pattern = fc.FcPatternCreate()
  fc.FcPatternAddString(pattern, b"family", family.encode())
  if lang != "-":
    fc.FcPatternAddString(pattern, b"lang", lang.encode())
  if char == "families":
    fc.FcConfigSubstitute(None, pattern, 0)
    print(fc.FcPatternFormat(pattern, b"%{family}").decode())
    continue
  if char != "-":
    charset = fc.FcCharSetCreate()
    fc.FcCharSetAddChar(charset, int(char, 16))
    fc.FcPatternAddCharSet(pattern, b"charset", charset)
  fc.FcConfigSubstitute(None, pattern, 0)
  fc.FcDefaultSubstitute(pattern)
  result = ctypes.c_int()
  print(fc.FcPatternFormat(fc.FcFontMatch(None, pattern, ctypes.byref(result)), b"%{family[0]}").decode())
PY

# resolve <locale> <string|langset> reads "family lang char" lines
resolve() {
  if [[ $2 == "string" ]]; then
    LANG=$1 python3 "$test_tmp/string-lang.py"
  else
    local family lang char query
    while read -r family lang char; do
      query=$family
      [[ $lang == "-" ]] || query+=":lang=$lang"
      [[ $char == "-" ]] || query+=":charset=$char"
      LANG=$1 fc-match -f '%{family[0]}\n' "$query"
    done
  fi
}

declare -A latin=([sans-serif]="Liberation Sans" [serif]="Liberation Serif" [monospace]="JetBrainsMono Nerd Font")
declare -A cjk=([sans-serif]="Noto Sans CJK" [serif]="Noto Serif CJK" [monospace]="Noto Sans Mono CJK")
declare -A variant=(
  [zh]=SC [zh-cn]=SC [zh-sg]=SC [zh-hans]=SC [zh-hans-cn]=SC [zh-hans-hk]=SC
  [zh-tw]=TC [zh-hant]=TC [zh-hant-tw]=TC
  [zh-hk]=HK [zh-mo]=HK [zh-hant-hk]=HK [zh-hant-mo]=HK
  [yue]=HK [yue-hk]=HK [yue-hant]=HK [yue-hant-hk]=HK [yue-hant-cn]=HK
  [yue-hans]=SC [yue-hans-cn]=SC [yue-hans-hk]=SC [yue-cn]=SC
  [ja]=JP [ja-jp]=JP [ko]=KR [ko-kr]=KR
)

queries=() expected=()
for tag in "${!variant[@]}"; do
  for generic in sans-serif serif monospace; do
    queries+=("$generic $tag -") expected+=("${latin[$generic]}")
    queries+=("$generic $tag 9aa8") expected+=("${cjk[$generic]} ${variant[$tag]}")
  done
done
for generic in sans-serif serif monospace; do
  queries+=("$generic - -") expected+=("${latin[$generic]}")
done

for locale in C.UTF-8 zh_CN.UTF-8; do
  for path in string langset; do
    mapfile -t actual < <(printf '%s\n' "${queries[@]}" | resolve "$locale" "$path")
    for i in "${!queries[@]}"; do
      [[ ${actual[i]} == "${expected[i]}" ]] ||
        fail "$locale $path lang: ${queries[i]} resolves to ${expected[i]}" "${actual[i]}"
    done
  done
  pass "$locale: tagged CJK keeps Omarchy's Latin families and sets Han in the tag's variant"
done

for path in string langset; do
  for generic in sans-serif serif monospace; do
    actual=$(echo "$generic - 9aa8" | resolve zh_CN.UTF-8 "$path")
    [[ $actual == "${cjk[$generic]} SC" ]] || fail "zh_CN $path: untagged Han in $generic is SC" "$actual"
  done
done
pass "a Chinese locale sets untagged Han in SC"

untouched=$(echo "sans-serif en families" | resolve C.UTF-8 string)
[[ $(echo "sans-serif ja families" | resolve C.UTF-8 string) != "$untouched" ]] ||
  fail "lang=ja changes the family list, so the prefix check below can see a match"
for tag in jam jav kok koi; do
  actual=$(echo "sans-serif $tag families" | resolve C.UTF-8 string)
  [[ $actual == "$untouched" ]] || fail "string lang=$tag is not taken for Japanese or Korean" "$actual"
done
pass "languages that only share a prefix with ja or ko get no CJK variant"
