# The setup form: every question Omarchy asks a human to describe their machine
# — keyboard, account, hostname, timezone — plus the rules those answers are
# checked against. Shared by the two places that ask them: the ISO
# configurator's user step and this package's first-boot owner setup
# (omarchy-provision-owner). Sourced by both, so the copies cannot drift the way
# the keyboard list already did.
#
# Every prompt reports one of three statuses, and both callers read them the
# same way:
#
#   0    field is set, move on
#   1    Esc — unwind to the start of the form
#   130  Ctrl+C — a per-caller side channel (the installer arms deferred
#        provisioning or toggles encryption; first-boot setup offers a reboot)
#
# gum is the reason those two are the whole vocabulary: Esc and Ctrl+C are the
# only keys any gum widget exits on, and Ctrl+C arrives as a byte in raw mode,
# so it never reaches the shell as SIGINT. Act on the status, never on a trap.
#
# Callers supply `notice <message> <seconds>` for validation feedback, and set
# the variables these prompts write: keyboard, keyboard_label,
# keyboard_input_method, keyboard_xkb_layout, username,
# password, password_confirmation, full_name, email_address, hostname, timezone.

OMARCHY_FORM_BACK=1
OMARCHY_FORM_SIGNAL=130

# The English layouts lead, then everything else alphabetically. gum choose
# paginates in --height-sized pages and jumps to the page holding --selected,
# so an alphabetical English (US) landed deep enough to sit alone at the edge
# of a page of layouts nobody scanning for it reads. Up here the default and
# its variants are the first thing on screen no matter how the list grows.
OMARCHY_KEYBOARD_LAYOUTS=$'English (US)|us
English (UK)|uk
English (US, Dvorak)|dvorak
English (US, Colemak)|colemak
Belarusian|by
Belgian|be-latin1
Bulgarian|bg-cp1251
Chinese (Simplified, Pinyin)|us|pinyin
Chinese (Traditional, Zhuyin)|us|chewing
Croatian|croat
Czech|cz
Danish|dk-latin1
Dutch|nl
Estonian|et
Finnish|fi
French|fr
French (Canada)|cf
French (Switzerland)|fr_CH
Georgian|ge
German|de
German (Switzerland)|de_CH-latin1
Greek|gr
Hebrew|il
Hungarian|hu
Icelandic|is-latin1
Irish|ie
Italian|it
Japanese|jp106|mozc
Japanese (US keyboard)|us|mozc
Kazakh|kazakh
Korean|us|hangul|kr
Kyrgyz|kyrgyz
Lao|us||la
Latvian|lv
Lithuanian|lt
Macedonian|mk-utf
Norwegian|no-latin1
Polish|pl
Portuguese|pt-latin1
Portuguese (Brazil)|br-abnt2
Romanian|ro
Russian|ru
Serbian|sr-latin
Slovak|sk-qwertz
Slovenian|slovene
Spanish|es
Spanish (Latin American)|la-latin1
Swedish|sv-latin1
Tajik|tj_alt-UTF8
Turkish|trq
Ukrainian|ua'

OMARCHY_USERNAME_PATTERN='^[a-z_][a-z0-9_-]*[$]?$'
OMARCHY_RESERVED_USERNAMES='^(root|bin|daemon|mail|ftp|http|nobody|dbus|systemd-coredump|systemd-network|systemd-oom|systemd-journal-remote|systemd-resolve|systemd-timesync|tss|uuidd|alpm|git|avahi|cups|cups-browsed|lp|_talkd|polkitd|rtkit|qemu|brltty|gluster|rpc|libvirt-qemu|pcscd|nvidia-persistenced|sddm)$'
OMARCHY_HOSTNAME_PATTERN='^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$'
OMARCHY_HOSTNAME_DEFAULT='omarchy'

# The ISO sets OMARCHY_INSTALL_LANG=zh in its CJK console; omarchy_text then prints the OMARCHY_ZH entry.
declare -gA OMARCHY_ZH=(
  ["Select keyboard layout"]="选择键盘布局"
  ["Alphanumeric without spaces (like dhh)"]="字母和数字，不含空格（如 dhh）"
  ["Username> "]="用户名> "
  ["Username is reserved for system"]="这个用户名由系统保留"
  ["That username already exists on this machine"]="本机已有这个用户名"
  ["Username must be alphanumeric with no spaces"]="用户名只能用字母和数字，不含空格"
  ["Used for user + root, and disk encryption when enabled"]="用于用户和 root，开启加密时也用于解锁磁盘"
  ["Password> "]="密码> "
  ["Must match the password you just typed"]="与刚才输入的密码一致"
  ["Confirm> "]="确认密码> "
  ["Your password can't be blank!"]="密码不能为空"
  ["Passwords didn't match!"]="两次输入的密码不一致"
  ["Used for git authentication (hit return to skip)"]="用于 git 身份（回车跳过）"
  ["Full name> "]="姓名> "
  ["Email address> "]="邮箱> "
  ["Letters, digits, and dashes (or return for 'omarchy')"]="字母、数字和连字符（回车用 omarchy）"
  ["Hostname> "]="主机名> "
  ["Hostname must be 1-63 letters, digits, or dashes, and cannot start or end with a dash"]="主机名为 1-63 个字母、数字或连字符，首尾不能是连字符"
  ["Timezone"]="时区"
)

omarchy_text() {
  local text=$1
  shift
  if [[ ${OMARCHY_INSTALL_LANG:-} == "zh" && -n ${OMARCHY_ZH[$text]:-} ]]; then
    text=${OMARCHY_ZH[$text]}
  fi
  # shellcheck disable=SC2059
  printf -- "$text" "$@"
}

# Installer targets are empty, so any account is fair game; first-boot setup
# overrides this because its machine already has users.
omarchy_username_taken() { return 1; }

# `x=$(gum ...) && status=0 || status=$?` rather than a bare assignment followed
# by `status=$?`: one caller runs under `set -e`, where a cancelled prompt is a
# failing assignment that would kill the script before the status is read.

# English or Simplified Chinese; the Chinese name shows only in a CJK console.
omarchy_prompt_language() {
  local chinese="Chinese" header="Select language" selected=English choice status
  if [[ -n ${OMARCHY_CJK_CONSOLE:-} ]]; then
    chinese="简体中文 Chinese"
    header="Select language · 选择语言"
  fi
  [[ $language == "zh" ]] && selected=$chinese
  choice=$(printf '%s\n' English "$chinese" | gum choose --selected "$selected" --header "$header") && status=0 || status=$?
  ((status == 0)) || return $status

  if [[ $choice == "English" ]]; then
    language=en
  else
    language=zh
  fi
}

# Callers may name the layout to preselect.
omarchy_prompt_keyboard() {
  local choice status selected=${1:-English (US)}
  choice=$(printf '%s\n' "$OMARCHY_KEYBOARD_LAYOUTS" | cut -d'|' -f1 |
    gum choose --height 10 --selected "${selected//,/\\,}" --header "$(omarchy_text "Select keyboard layout")") && status=0 || status=$?
  ((status == 0)) || return $status

  local selection
  selection=$(printf '%s\n' "$OMARCHY_KEYBOARD_LAYOUTS" | awk -F'|' -v c="$choice" '$1==c{print; exit}')
  [[ -n $selection ]] || return 1
  IFS='|' read -r keyboard_label keyboard keyboard_input_method keyboard_xkb_layout <<< "$selection"
  keyboard_input_method=${keyboard_input_method:-none}
  keyboard_xkb_layout=${keyboard_xkb_layout:-}
}

# Root-side persistence. Console keymaps remain real keymaps; the input
# preference survives separately for every user of the installed system.
omarchy_persist_input_selection() {
  local target_root=${1:-} method=${keyboard_input_method:-none} layout=${keyboard_xkb_layout:-}
  case "$method" in none | mozc | hangul | pinyin | chewing) ;; *) return 1 ;; esac
  case "$layout" in "" | kr | la) ;; *) return 1 ;; esac
  mkdir -p "$target_root/etc/omarchy"
  printf 'INPUT_METHOD=%s\nXKB_LAYOUT=%s\n' "$method" "$layout" > "$target_root/etc/omarchy/input-method"
}

omarchy_prompt_username() {
  local status
  while true; do
    username=$(gum input --placeholder "$(omarchy_text "Alphanumeric without spaces (like dhh)")" --prompt.foreground="#845DF9" --prompt "$(omarchy_text "Username> ")") && status=0 || status=$?
    ((status == 0)) || return $status

    if [[ "$username" =~ $OMARCHY_USERNAME_PATTERN ]]; then
      if [[ "$username" =~ $OMARCHY_RESERVED_USERNAMES ]]; then
        notice "$(omarchy_text "Username is reserved for system")" 1
      elif omarchy_username_taken "$username"; then
        notice "$(omarchy_text "That username already exists on this machine")" 1
      else
        return 0
      fi
    else
      notice "$(omarchy_text "Username must be alphanumeric with no spaces")" 1
    fi
  done
}

omarchy_prompt_password() {
  local status
  while true; do
    password=$(gum input --placeholder "$(omarchy_text "Used for user + root, and disk encryption when enabled")" --prompt.foreground="#845DF9" --password --prompt "$(omarchy_text "Password> ")") && status=0 || status=$?
    ((status == 0)) || return $status
    password_confirmation=$(gum input --placeholder "$(omarchy_text "Must match the password you just typed")" --prompt.foreground="#845DF9" --password --prompt "$(omarchy_text "Confirm> ")") && status=0 || status=$?
    ((status == 0)) || return $status

    if [[ -n "$password" && "$password" == "$password_confirmation" ]]; then
      return 0
    elif [[ -z "$password" ]]; then
      notice "$(omarchy_text "Your password can't be blank!")" 1
    else
      notice "$(omarchy_text "Passwords didn't match!")" 1
    fi
  done
}

# Both fields are skippable with Return, so an empty value is a real answer and
# only Esc/Ctrl+C end the prompt early.
omarchy_prompt_identity() {
  local status
  full_name=$(gum input --placeholder "$(omarchy_text "Used for git authentication (hit return to skip)")" --prompt.foreground="#845DF9" --prompt "$(omarchy_text "Full name> ")") && status=0 || status=$?
  ((status == 0)) || return $status
  email_address=$(gum input --placeholder "$(omarchy_text "Used for git authentication (hit return to skip)")" --prompt.foreground="#845DF9" --prompt "$(omarchy_text "Email address> ")") && status=0 || status=$?
  return $status
}

omarchy_prompt_hostname() {
  local status
  while true; do
    hostname=$(gum input --placeholder "$(omarchy_text "Letters, digits, and dashes (or return for 'omarchy')")" --prompt.foreground="#845DF9" --prompt "$(omarchy_text "Hostname> ")") && status=0 || status=$?
    ((status == 0)) || return $status

    if [[ -z $hostname ]]; then
      hostname="$OMARCHY_HOSTNAME_DEFAULT"
      return 0
    elif [[ "$hostname" =~ $OMARCHY_HOSTNAME_PATTERN ]]; then
      return 0
    else
      notice "$(omarchy_text "Hostname must be 1-63 letters, digits, or dashes, and cannot start or end with a dash")" 1
    fi
  done
}

# A fresh machine often hasn't joined a network yet, so the geo guess fails
# often; guard it or a `set -e` caller dies before the filter fallback.
omarchy_prompt_timezone() {
  local guess status
  guess=$(tzupdate -p 2>/dev/null) || guess=""

  if [[ -n $guess ]]; then
    timezone=$(timedatectl list-timezones | gum choose --height 10 --selected "$guess" --header "$(omarchy_text "Timezone")") && status=0 || status=$?
  else
    timezone=$(timedatectl list-timezones | gum filter --height 10 --header "$(omarchy_text "Timezone")") && status=0 || status=$?
  fi
  ((status == 0)) || return $status

  [[ -n $timezone ]] || timezone="UTC"
}
