cn_links=(
  "environment.conf /etc/environment.d/90-omarchy-china.conf"
  "cargo.toml /.cargo/config.toml"
  "gemrc /etc/gemrc"
)

# The installer writes the marker from the timezone.
region=global
if [[ -e /etc/omarchy/region ]]; then
  region=$(</etc/omarchy/region)
fi

case $region in
global) ;;
cn)
  for link in "${cn_links[@]}"; do
    read -r _ target <<<"$link"
    if [[ -e $target && ! -L $target ]]; then
      echo "Refusing to replace $target, which Omarchy did not create" >&2
      exit 1
    fi
  done
  for link in "${cn_links[@]}"; do
    read -r source target <<<"$link"
    mkdir -p "${target%/*}"
    ln -sfn "$OMARCHY_PATH/default/regions/cn/$source" "$target"
  done
  ;;
*)
  echo "Unknown region: $region" >&2
  exit 1
  ;;
esac
