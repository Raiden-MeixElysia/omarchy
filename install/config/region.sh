cn_links=(
  "environment.conf /etc/environment.d/90-omarchy-china.conf"
  "cargo.toml /.cargo/config.toml"
  "gemrc /etc/gemrc"
)

# The installer writes the marker from the timezone; omarchy-region passes the region it switches to.
region=global
if [[ -e /etc/omarchy/region ]]; then
  region=$(</etc/omarchy/region)
fi
region=${OMARCHY_REGION:-$region}

case $region in
global)
  rm -f /etc/omarchy/region
  for link in "${cn_links[@]}"; do
    read -r _ target <<<"$link"
    if [[ -L $target && $(readlink "$target") == */default/regions/cn/* ]]; then
      rm "$target"
    fi
  done
  ;;
cn)
  for link in "${cn_links[@]}"; do
    read -r _ target <<<"$link"
    if [[ -e $target && ! -L $target ]]; then
      echo "Refusing to replace $target, which Omarchy did not create" >&2
      exit 1
    fi
  done
  mkdir -p /etc/omarchy
  echo cn >/etc/omarchy/region
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
