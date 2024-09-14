#!/bin/bash
#POSIX
# set -o xtrace

# NOTE: get os name
os=""
if [ -r /etc/os-release ]; then
    os="$(. /etc/os-release && echo "$ID")"
fi
echo "OS Release: ${os}"

kUpdate=0
kInstall=0
kBackUp=0
kUpdateVim=0
while getopts u:i:n:b: flag; do
    case "${flag}" in
    u) kUpdate=${OPTARG} ;;
    i) kInstall=${OPTARG} ;;
    n) kUpdateVim=${OPTARG} ;;
    b) kBackUp=${OPTARG} ;;
    *)
        echo "Usage: $0 [-u update] [-i install] [-n updateVim] [-b backUp]"
        exit 1
        ;;
    esac
done

chmod +x ./scripts/*

# NOTE: BackUp
if [[ ${kBackUp} == 1 ]]; then
    find dotfyles -type f | awk '{sub(/^dotfyles\//, ""); print}' | while IFS= read -r FILE; do
        echo ">>>>> Backing up ${FILE}..."
        prefix=$(echo "$FILE" | awk 'BEGIN {FS=OFS="/"} {NF--; print}')
        cp "${HOME}/${FILE}" "dotfyles/${prefix}/"
    done
fi

# PERF: Update
if [[ ${kUpdate} == 1 ]]; then
    # NOTE: COPY file
    rsync -r --no-perms --no-owner --include="*/" --include=".*" "dotfyles/" "${HOME}/"

    # NOTE: neovim
    if [[ ${kUpdateVim} == 1 ]]; then
        echo ">>>>> Updating neovim/vim..."
        ./scripts/install_nvim.sh
        ./scripts/install_vim.sh
    fi

    # NOTE: neovim dependencies
    if [[ ${os} == "rocky" ]]; then
        export NVM_DIR=$HOME/.nvm
        source "$NVM_DIR/nvm.sh"
        "nvm" install --lts

        ./scripts/install_cppcheck.sh
        ./scripts/install_ripgrep.sh

    elif [[ ${os} == "ubuntu" ]]; then
        sudo apt update && sudo apt upgrade -y
    elif [[ ${os} == "arch" ]]; then
        sudo pacman -Syu
    fi

    # NOTE: cargo related stuffs
    if cargo install --list | grep -q 'cargo-update'; then
        cargo install-update -a
    else
        cargo install cargo-update
        cargo install-update -a
    fi

    source "${HOME}/.zshrc"
    tmux source "${HOME}/.tmux.conf"
fi

# PERF: Install
if [[ ${kInstall} == 1 ]]; then
    # NOTE: shell stuffs
    rsync -r --no-perms --no-owner --include="*/" --include=".*" "dotfyles/" "${HOME}/"

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo ">>>>> Installing oh-my-zsh..."
        ./scripts/install_omz.sh
    fi

    export NVM_DIR=$HOME/.nvm
    source "$NVM_DIR/nvm.sh"
    "nvm" install --lts

    # NOTE: cargo
    if ! ./scripts/check_exe.sh "cargo" "1.80.0"; then
        echo ">>>>> Installing rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        rustup update
    fi

    if ! cargo install --list | grep -q "yazi-fm"; then
        echo ">>>>> Installing yazi for file navigation..."
        cargo install --locked yazi-fm yazi-cli
    fi

    # NOTE: zoxide
    if ! command -v "zoxide" &>/dev/null; then
        echo ">>>>> installing zoxide..."
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi

    # NOTE: install nvim/vim
    mkdir -p "${HOME}/bin/repos"
    if [[ ${kUpdateVim} == 1 ]]; then
        if ./scripts/check_exe.sh "nvim" "0.10.0"; then
            ./scripts/install_nvim.sh
        fi
        if ./scripts/check_exe.sh "vim" "9.0"; then
            ./scripts/install_vim.sh
        fi
    fi

    source "${HOME}/.zshrc"
    tmux source "${HOME}/.tmux.conf"
    # NOTE: install the dependencies for neovim
    if [[ ${os} == "rocky" ]]; then
        if ! command -v cppcheck &>/dev/null; then
            echo ">>>>> Installing cppcheck..."
            ./scripts/install_cppcheck.sh
        fi
        if ! command -v rg &>/dev/null; then
            echo ">>>>> Installing ripgrep..."
            ./scripts/install_ripgrep.sh
        fi
    elif [[ ${os} == "ubuntu" ]]; then
        echo ">>>>> Installing clang-tidy..."
        sudo apt install clang-tidy

        echo ">>>>> Installing wezterm..."
        git clone https://github.com/RomaLzhih/wezterm-config.git ~/.config/wezterm
    elif [[ ${os} == "arch" ]]; then
        echo ">>>>> Installing clang-tidy..."
        sudo pacman -S clang-tidy

        echo ">>>>> Installing wezterm..."
        git clone https://github.com/RomaLzhih/wezterm-config.git ~/.config/wezterm
    fi

    source "${HOME}/.zshrc"
    tmux source "${HOME}/.tmux.conf"
fi

echo ">>>>>> Done! Have a good day!"
