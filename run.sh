#!/bin/bash
#POSIX
# set -o xtrace

version_lt() {
    [ "$1" = "$2" ] && return 1 || [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

# NOTE: helper function to git git status
CheckDiffStatus() {
    cur_path=${PWD}
    check_path=$1
    debug_mode=$2
    cd "${check_path}" || exit
    git diff --quiet
    changes=$?
    if [[ ${changes} == "1" ]]; then
        echo "Changes detected in ${check_path}, please commit first."
        if [[ ${debug_mode} == 1 ]]; then
            exit 1
        fi
    fi
    cd "${cur_path}" || exit
}

# NOTE: get os name
os=""
if [ -r /etc/os-release ]; then
    os="$(. /etc/os-release && echo "$ID")"
fi
echo "OS Release: ${os}"

kUpdate=0
kInstall=0
kForceUpdate=0
kUpdateNeovim=0
debug=0
while getopts u:i:p:f:d:n: flag; do
    case "${flag}" in
    u) kUpdate=${OPTARG} ;;
    i) kInstall=${OPTARG} ;;
    f) kForceUpdate=${OPTARG} ;;
    d) debug=${OPTARG} ;;
    n) kUpdateNeovim=${OPTARG} ;;
    *) echo "Running default settings: only update, without discard changes in git" ;;
    esac
done

if [[ ${kForceUpdate} == 0 ]]; then
    CheckDiffStatus "${PWD}" "${debug}"
else
    git reset --hard
fi

# PERF: Update
if [[ ${kUpdate} == 1 ]]; then

    # NOTE: COPY file
    rsync -a --include='.*' .config "${HOME}/"
    cp dotfyles/.tmux.conf "${HOME}/"
    cp dotfyles/.vimrc "${HOME}/"
    cp dotfyles/.zshrc "${HOME}/"

    # NOTE: neovim
    if [[ ${kUpdateNeovim} == 1 ]]; then
        cd "${HOME}/bin/repos/neovim" || exit
        git checkout master
        git fetch
        if [[ "$(git rev-parse HEAD)" != "$(git rev-parse @{u})" ]]; then
            git checkout master
            git pull
            if [[ ${os} == "rocky" ]]; then
                git checkout release-0.10
            fi
            make CMAKE_BUILD_TYPE=Release CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/neovim"
            make install
            export PATH="$HOME/neovim/bin:$PATH"

            #NOTE: once recompiled, needs to rebuilds the neovim config
            rm -rf ~/.config/nvim
            rm -rf ~/.local/share/nvim
            git clone git@github.com:RomaLzhih/neovim_config.git ~/.config/nvim
        fi
    fi

    # NOTE: neovim configuration
    if [[ ${kForceUpdate} == 0 ]]; then
        CheckDiffStatus "${HOME}/.config/nvim" "${debug}"
    else
        cd "${HOME}/.config/nvim" || exit
        git reset --hard && git pull
    fi

    # NOTE: neovim dependencies
    if [[ ${os} == "rocky" ]]; then
        cd "${HOME}" || exit

        export NVM_DIR=$HOME/.nvm
        source $NVM_DIR/nvm.sh
        nvm install lts --reinstall-packages-from=current

        python3 -m pip install --upgrade pip setuptools wheel
        python3 -m pip install clang-tidy -U
        python3 -m pip install cpplint -U
        python3 -m pip install black -U
        python3 -m pip install pandas-stubs -U
        python3 -m pip install pynvim -U

        cd "${HOME}/bin/repos/cppcheck" || exit
        git fetch
        if [[ "$(git rev-parse HEAD)" != "$(git rev-parse @{u})" ]]; then
            git pull
            rm -rf build
            mkdir -p build
            cd "build" || exit
            cmake ..
            cmake --build .
            cd "${HOME}/bin/" || exit
            rm cppcheck
            ln -s "${HOME}/bin/repos/cppcheck/build/bin/cppcheck" ~/bin/cppcheck
        fi

        cd "${HOME}/bin/repos/ripgrep" || exit
        git fetch
        if [[ "$(git rev-parse HEAD)" != "$(git rev-parse @{u})" ]]; then
            git pull
            cargo build --release
            ./target/release/rg --version
            cd "${HOME}/bin/" || exit
            rm rg
            ln -s "${HOME}/bin/repos/ripgrep/target/release/rg" ~/bin/rg
        fi

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
    cd "${HOME}" || exit

    rsync -a --include='.*' .config "${HOME}/"
    cp dotfyles/.tmux.conf "${HOME}/"
    cp dotfyles/.vimrc "${HOME}/"
    cp dotfyles/.zshrc "${HOME}/"
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "OMZ installed"
    else
        ./scripts/install_omz.sh
    fi

    export NVM_DIR=$HOME/.nvm
    source "$NVM_DIR/nvm.sh"
    "nvm" install --lts

    # NOTE: cargo
    installed_version=$(cargo --version 2>/dev/null | awk '{print $2}')
    required_version="1.8.0"
    if version_lt "$installed_version" "$required_version"; then
        echo "install latest cargo ... "
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        rustup update
    fi

    if ! cargo install --list | grep -q "yazi-fm"; then
        cargo install --locked yazi-fm yazi-cli
    fi

    # NOTE: zoxide
    if command -v zoxide &>/dev/null; then
        echo "install zoxide"
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi

    source "${HOME}/.zshrc"
    tmux source "${HOME}/.tmux.conf"

    # NOTE: check if neovim is installed
    if ! [ -x "$(command -v nvim)" ]; then
        ./scripts/install_nvim.sh
    fi

    # NOTE: install the neovim config
    rm -rf ~/.config/nvim
    rm -rf ~/.local/share/nvim
    git clone git@github.com:RomaLzhih/neovim_config.git ~/.config/nvim

    ./scripts/install_vim.sh

    # NOTE: install the dependencies for neovim
    if [[ ${os} == "rocky" ]]; then
        cd "${HOME}" || exit
        # NOTE: python env
        python3 -m venv .venv
        source .venv/bin/activate
        python3 -m pip --version
        python3 -m pip install --upgrade pip setuptools wheel
        python3 -m pip install clang-tidy
        python3 -m pip install cpplint
        python3 -m pip install black
        python3 -m pip install pandas-stubs
        python3 -m pip install pynvim
        go install mvdan.cc/sh/v3/cmd/shfmt@latest

        # NOTE: build from source
        mkdir -p "${HOME}/bin/repos"

        ./scripts/install_cppcheck.sh
        ./scripts/install_ripgrep.sh

    elif [[ ${os} == "ubuntu" ]]; then
        sudo apt install clang-tidy cpplint black cppcheck ripgrep nodejs
        git clone https://github.com/RomaLzhih/wezterm-config.git ~/.config/wezterm
    elif [[ ${os} == "arch" ]]; then
        sudo pacman -S clang-tidy cpplint black cppcheck ripgrep nodejs
        git clone https://github.com/RomaLzhih/wezterm-config.git ~/.config/wezterm
    fi
fi

echo ">>>>>> Done! Have a good day!"
