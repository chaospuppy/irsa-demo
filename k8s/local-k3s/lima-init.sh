#!/bin/bash
set -eu -o pipefail

usage() {
  cat << EOF
  usage:
  $0 [limafile]
  Options:
  limafile - File to be fed to limactl to configure the lima VM
EOF
}

limafile=${1:-"irsa-k3s.yaml"}
limaname=$(echo "$limafile" | cut -d. -f1)

osx_install(){
  declare -a deps=(lima docker docker-compose)

  for dep in "${deps[@]}"; do
    if ! command -v $dep 2>&1 >/dev/null ; then
      echo "installing $dep"
      brew install $dep
    fi
  done
}

if [[ "$OSTYPE" == "darwin"* ]]; then
  osx_install
fi

limactl start --tty=false $limafile

if [[ $limafile == "irsa-k3s.yaml" ]]; then
  mkdir -p "${HOME}/.lima/$limaname/conf"
  kubeconfig="${HOME}/.lima/$limaname/conf/kubeconfig.yaml"
  limactl shell $limaname sudo cat /etc/rancher/k3s/k3s.yaml >$kubeconfig
  if command -v kubeconfig-combine 2>&1 >/dev/null ; then
    kubeconfig-combine --allow-overwrite --all-name $limaname $kubeconfig
  fi
fi
