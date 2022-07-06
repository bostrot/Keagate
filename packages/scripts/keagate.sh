#!/bin/bash

set -uo pipefail

# OS="$(uname -s)"
if [ -n "$SUDO_USER" ]; then
    HOME="$(getent passwd $SUDO_USER | cut -d: -f6)"
fi

INSTALL_DIR="$HOME"
FOLDER_NAME="Keagate"
REPO_LOCATION="https://github.com/dilan-dio4/$FOLDER_NAME"
NODE_ARGS=""

# yes/no script
# read -p "Are you sure? " -n 1 -r
# echo    # (optional) move to a new line
# if [[ $REPLY =~ ^[Yy]$ ]]
# then
#     ...do dangerous stuff
# fi

# https://github.com/DevelopersToolbox/bash-spinner

# Parse Flags
for i in "$@"; do
    case $i in
    -q | --quiet)
        QUIET="true"
        NODE_ARGS+="$key "
        shift # past argument
        # shift # past value
        ;;
    -v | --verbose)
        VERBOSE="true"
        NODE_ARGS+="$key "
        shift # past argument
        # shift # past value
        ;;
    *)
        keagate_echo "Unrecognized argument $key"
        exit 1
        ;;
    esac
done

keagate_has() {
    type "$1" >/dev/null 2>&1
}

keagate_echo() {
    command printf %s\\n "$*" 2>/dev/null
}

keagate_debug() {
    if [ -n "$VERBOSE" ]; then
        command printf %s\\n "$*" 2>/dev/null
    fi
}

print_complete() {
    echo -e "\033[1;32m\xE2\x9C\x94 Complete"
}

install_node() {
    keagate_echo "Installing Node and NPM via nvm..."
    curl -s -o nvm.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh
    chmod +x ./nvm.sh
    export NVM_DIR="$HOME/.nvm"
    ./nvm.sh >/dev/null 2>&1
    rm ./nvm.sh
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
    nvm install 16 >/dev/null 2>&1
    nvm use 16 >/dev/null 2>&1
    print_complete
}

# https://stackoverflow.com/a/42876846
# if [[ "$EUID" = 0 ]]; then
#     keagate_debug "Privilege check: already root"
# else
#     sudo -k # make sure to ask for password on next sudo
#     if sudo true; then
#         keagate_debug "Privilege check: Correct password"
#     else
#         keagate_debug "Privilege check: wrong password"
#         echo "Wrong password. Please try again."
#         exit 1
#     fi
# fi

if ! keagate_has "docker"; then
    keagate_echo "\`Docker\` command not found. Installing..."
    # Install Docker - used for Mongo and Nginx
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh >/dev/null 2>&1
    rm get-docker.sh
    print_complete
fi

# Fix permissions issue on certain ports from `docker run`
sudo chmod 666 /var/run/docker.sock

if keagate_has "node" && keagate_has "npm"; then
    keagate_echo "Node and NPM detected. Checking versions..."
    installed_node_version=$(node --version | cut -c 2-3)
    keagate_echo "Installed node version: $installed_node_version"
    if (("$installed_node_version" < "14")); then
        echo
        read -p "Your existing node version ($installed_node_version) is too low for Keagate. Would you like me to automatically upgrade Node and NPM? (You can revert back with \`nvm install $installed_node_version && nvm use $installed_node_version\`) [Y/n] " -n 1 -r
        echo # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_node
        else
            keagate_echo "Please manually upgrade Node to at least version 14, then run this script again."
            exit 1
        fi
    fi
else
    keagate_echo "Node and NPM not detected on this machine."
    install_node
fi

cd $INSTALL_DIR

if [ -d "$FOLDER_NAME" ]; then
    keagate_debug "Found an existing $FOLDER_NAME/. Asking for permission to override..."
    echo
    read -p "Folder $FOLDER_NAME/ already exists in $INSTALL_DIR. Would you like me to overwrite this? (This will preserve \`config/local.json\`) [Y/n] " -n 1 -r
    echo # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        keagate_debug "Caching existing local.json to a temporary file..."
        cp -f $FOLDER_NAME/config/local.json ./local.json || true
        rm -rf $FOLDER_NAME
        echo "Cloning Keagate repo..."
        git clone $REPO_LOCATION >/dev/null 2>&1
        cp -f ./local.json $FOLDER_NAME/config/local.json || true
        rm -f ./local.json || true
    fi
else
    echo "Cloning Keagate repo..."
    git clone $REPO_LOCATION >/dev/null 2>&1
fi

print_complete

cd $FOLDER_NAME

# >/dev/null 2>&1

echo "Installing and configuring pnpm..."
npm i -g pnpm >/dev/null 2>&1
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
pnpm setup >/dev/null 2>&1
print_complete

echo "Installing Keagate dependencies..."
pnpm i --silent -g pm2
pnpm i --silent
print_complete

echo "Building Keagate..."
pnpm run build >/dev/null 2>&1
print_complete

echo -e '\0033\0143'
node packages/scripts/build/configure.js $NODE_ARGS

# pnpm run start
