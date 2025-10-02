#!/bin/bash
# Bootstrap script to install and call Ansible.
# This must be run as root.
# Exit on error. Append "|| true" if you expect an error.
set -o errexit 
# Exit on error inside any function or subshells.  
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR.
set -o nounset 
# Catch the error in case cmd1 fails (but cmd2 succeeds) in  `cmd1 | cmd2 `.
set -o pipefail
# Turn on traces, useful while debugging but commentend out by default
# set -o xtrace

repo_path=""

echo "Sanity checks..."

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: wrong OS detected."
  echo "please run this on macOS."
  echo "exiting..."
  exit 1
fi

# check macOS version.
# Pkgsrc on Apple Silicon requires macOS 14.5 but requires 12.3 on Intel, so 
# I'm checking for at least macOS 14.
if [ "$(sw_vers -productversion | awk -F '.' '{print $1}')" -lt 14 ]; then
  echo "ERROR: macOS version too low."
  echo "please use at least macOS 14 'Sonoma'"
  echo "exiting..."
  exit 1
fi

echo "Alright, everything checks out."

echo "Installing software dependencies..."
# Both Homebrew and Pkgsrc are installed, because the former has cask and mas,
# which allow me to install graphical software outside and from the Mac App Store,
# just as if they were in a repository.
# Moreover, Homebrew installation automatically pulls macOS developer tools.
# I could just install Homebrew but I contribute to Pkgsrc, so... ;-)

dl_path="$(mktemp -d)"
# Homebrew
if [ ! -f /opt/homebrew/bin/brew ]; then
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
	  --output "${dl_path}/brew_installer.sh"
  chmod +x "${dl_path}/brew_installer.sh"
  NONINTERACTIVE=1 "${dl_path}/brew_installer.sh"
	/opt/homebrew/bin/brew install mas 2>&1 /dev/null
fi

# Pkgsrc
# Following instructions in https://pkgsrc.joyent.com/install-on-macos/
arch=$(uname -m)
case $arch in
  x86_64) # Intel
    BOOTSTRAP_TAR="bootstrap-macos12.3-trunk-x86_64-20240426.tar.gz"
    BOOTSTRAP_SHA="2b151d12576befd85312ddb5261307998f16df2f"
    ;;
  arm64) # Apple Silicon
    BOOTSTRAP_TAR="bootstrap-macos14.5-trunk-arm64-20250905.tar.gz"
    BOOTSTRAP_SHA="30565b8e6a6af562d4585055938addc443c0dcda"
    ;;
  *)
    echo "ERROR: invalid CPU architecture."
    echo "exiting..."
    exit 1
    ;;
esac

if [ ! -f /opt/pkg/bin/pkgin ]; then
	curl https://pkgsrc.smartos.org/packages/Darwin/bootstrap/${BOOTSTRAP_TAR} \
		--output "${dl_path}/${BOOTSTRAP_TAR}"
	cd "${dl_path}"
	echo "${BOOTSTRAP_SHA}  ${BOOTSTRAP_TAR}" | shasum -c-
	sudo tar -zxpf ${BOOTSTRAP_TAR} -C /
	eval "$(/usr/libexec/path_helper)"
	cd -
	sudo /opt/pkg/bin/pkgin -f update 2>&1 /dev/null
	sudo /opt/pkg/bin/pkgin -y upgrade 2>&1 /dev/null
fi

if [ ! -f /opt/pkg/bin/ansible ]; then
  sudo /opt/pkg/bin/pkgin -y install ansible 2>&1 /dev/null
fi
echo "Done !"

echo "Pulling the repository..."
repo_path="$(mktemp -d)"
cd "${repo_path}"
git clone https://github.com/ahpnils/bootstrap-workstation-macos.git
echo "Done !"

echo "Executing the playbook..."
cd "${repo_path}/bootstrap-workstation-macos"
ansible-galaxy collection install geerlingguy.mac
ANSIBLE_LOCALHOST_WARNING=False \
	/opt/pkg/bin/ansible-playbook ./ansible/playbooks/bootstrap_workstation_macos.yml
echo "Done !"
 
echo "Clean-up phase..."
cd "${OLDPWD}"
rm -rf "${dl_path}"
rm -rf "${repo_path}"
echo "Done !"

echo "Your desktop environment is almost ready, please reboot it before using it."

# vim:ts=2:sw=2
