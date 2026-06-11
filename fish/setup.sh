#!/bin/bash

set -e

FISH_ENV_BLOCK_START="# >>> shell-env fish-env >>>"
FISH_ENV_BLOCK_END="# <<< shell-env fish-env <<<"
LEGACY_FISH_ENV_BLOCK_START="# >>> bash-env-setup fish-env >>>"
LEGACY_FISH_ENV_BLOCK_END="# <<< bash-env-setup fish-env <<<"
LEGACY_FISH_PATH_BLOCK_START="# >>> bash-env-setup fish-path >>>"
LEGACY_FISH_PATH_BLOCK_END="# <<< bash-env-setup fish-path <<<"
FISH_PROMPT_BLOCK_START="# >>> shell-env fish-prompt >>>"
FISH_PROMPT_BLOCK_END="# <<< shell-env fish-prompt <<<"
LEGACY_FISH_PROMPT_BLOCK_START="# >>> bash-env-setup fish-prompt >>>"
LEGACY_FISH_PROMPT_BLOCK_END="# <<< bash-env-setup fish-prompt <<<"
FISH_COLORS_BLOCK_START="# >>> shell-env fish-colors >>>"
FISH_COLORS_BLOCK_END="# <<< shell-env fish-colors <<<"
LEGACY_FISH_COLORS_BLOCK_START="# >>> bash-env-setup fish-colors >>>"
LEGACY_FISH_COLORS_BLOCK_END="# <<< bash-env-setup fish-colors <<<"
FISH_LATEST_RELEASE_API="https://api.github.com/repos/fish-shell/fish-shell/releases/latest"

print_help() {
    cat <<EOF
Usage:
  bash fish/setup.sh                    # install fish + env + prompt + colors + vim
  bash fish/setup.sh install            # install fish only
  bash fish/setup.sh env                # install fish env block only
  bash fish/setup.sh path               # alias for env
  bash fish/setup.sh prompt             # install fish prompt config only
  bash fish/setup.sh colors             # install fish color overrides only
  bash fish/setup.sh vim                # install vim config only
  bash fish/setup.sh uninstall-env      # remove the env block
  bash fish/setup.sh uninstall-path     # alias for uninstall-env
  bash fish/setup.sh uninstall-prompt
  bash fish/setup.sh uninstall-colors
  bash fish/setup.sh env prompt colors  # run multiple modes in order
  bash fish/setup.sh [--help|-h]

Description:
  Installs the fish shell plus optional env, prompt, color, and vim config.

Supported package managers:
  apt-get, dnf, yum, apk, pacman, zypper, brew
  On apt systems where fish cannot be installed from configured
  repositories, installs the latest GitHub Linux release to /usr/local/bin.

Env behavior:
  Adds a managed block to ~/.config/fish/config.fish that prepends
  ~/.local/bin when it is not already present in PATH, sets EDITOR and
  VISUAL to vim, and sets LS_COLORS.

Prompt behavior:
  Adds a managed block to ~/.config/fish/config.fish that defines
  fish_prompt with a Git Bash-style layout: green user@host, cyan full
  \$PWD, light orange git status with color hints (green branch, red
  dirty/untracked markers), a right-aligned timestamp, and the command
  on a new line.

Color behavior:
  Adds a managed block to ~/.config/fish/config.fish that aligns fish
  command-line syntax colors with Bash's terminal-default input foreground
  while keeping prompt, status, autosuggestion, search, and pager colors
  readable on dark backgrounds.
EOF
}

install_fish() {
    if command -v fish >/dev/null 2>&1; then
        echo "fish already installed: $(command -v fish) ($(fish --version 2>/dev/null))"
        return 0
    fi

    local sudo=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo="sudo"
        else
            echo "Error: not running as root and sudo is not available." >&2
            return 1
        fi
    fi

    if command -v apt-get >/dev/null 2>&1; then
        echo "Installing fish via apt-get..."
        if $sudo apt-get update && $sudo apt-get install -y fish; then
            :
        else
            echo "Unable to install fish via apt-get; installing latest release from GitHub..."
            install_fish_from_github_release "${sudo}" || return 1
        fi
    elif command -v dnf >/dev/null 2>&1; then
        echo "Installing fish via dnf..."
        $sudo dnf install -y fish
    elif command -v yum >/dev/null 2>&1; then
        echo "Installing fish via yum..."
        $sudo yum install -y fish
    elif command -v apk >/dev/null 2>&1; then
        echo "Installing fish via apk..."
        $sudo apk add fish
    elif command -v pacman >/dev/null 2>&1; then
        echo "Installing fish via pacman..."
        $sudo pacman -Sy --noconfirm fish
    elif command -v zypper >/dev/null 2>&1; then
        echo "Installing fish via zypper..."
        $sudo zypper install -y fish
    elif command -v brew >/dev/null 2>&1; then
        echo "Installing fish via brew..."
        brew install fish
    else
        echo "Error: no supported package manager found (apt-get, dnf, yum, apk, pacman, zypper, brew)." >&2
        return 1
    fi

    if ! command -v fish >/dev/null 2>&1; then
        echo "Error: fish installation completed but 'fish' is not on PATH." >&2
        return 1
    fi

    echo "fish installed: $(command -v fish) ($(fish --version 2>/dev/null))"
}

download_to_stdout() {
    local url="$1"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${url}"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "${url}"
    else
        echo "Error: curl or wget is required to download fish from GitHub." >&2
        return 1
    fi
}

download_to_file() {
    local url="$1"
    local output_file="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fL "${url}" -o "${output_file}"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "${output_file}" "${url}"
    else
        echo "Error: curl or wget is required to download fish from GitHub." >&2
        return 1
    fi
}

ensure_fish_github_dependencies() {
    local sudo="$1"

    if (command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1) &&
        command -v xz >/dev/null 2>&1; then
        return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
        echo "Installing GitHub download dependencies..."
        $sudo apt-get install -y ca-certificates curl xz-utils
        return 0
    fi

    echo "Error: curl or wget and xz are required to download fish from GitHub." >&2
    return 1
}

fish_linux_arch() {
    case "$(uname -m)" in
        x86_64 | amd64)
            echo "x86_64"
            ;;
        aarch64 | arm64)
            echo "aarch64"
            ;;
        *)
            echo "Error: unsupported Linux architecture for fish GitHub install: $(uname -m)" >&2
            return 1
            ;;
    esac
}

latest_fish_version() {
    download_to_stdout "${FISH_LATEST_RELEASE_API}" |
        sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' |
        sed -n '1p'
}

install_fish_from_github_release() {
    local sudo="$1"
    local arch version archive_name download_url tmpdir archive_file fish_binary

    ensure_fish_github_dependencies "${sudo}" || return 1

    arch="$(fish_linux_arch)" || return 1
    version="$(latest_fish_version)" || return 1

    if [[ -z "${version}" ]]; then
        echo "Error: could not determine latest fish release version from GitHub." >&2
        return 1
    fi

    archive_name="fish-${version}-linux-${arch}.tar.xz"
    download_url="https://github.com/fish-shell/fish-shell/releases/download/${version}/${archive_name}"
    tmpdir="$(mktemp -d)" || return 1
    archive_file="${tmpdir}/${archive_name}"
    fish_binary="${tmpdir}/fish"

    if ! download_to_file "${download_url}" "${archive_file}"; then
        rm -rf "${tmpdir}"
        return 1
    fi

    if ! tar -xJf "${archive_file}" -C "${tmpdir}"; then
        echo "Error: could not extract downloaded fish archive." >&2
        rm -rf "${tmpdir}"
        return 1
    fi

    if [[ ! -x "${fish_binary}" ]]; then
        echo "Error: downloaded fish archive did not contain an executable 'fish'." >&2
        rm -rf "${tmpdir}"
        return 1
    fi

    if ! $sudo install -d /usr/local/bin ||
        ! $sudo install -m 755 "${fish_binary}" /usr/local/bin/fish; then
        rm -rf "${tmpdir}"
        return 1
    fi

    rm -rf "${tmpdir}"
}

remove_fish_prompt_block() {
    local config_file="$1"

    [[ -f "${config_file}" ]] || return 0
    sed -i "/${FISH_PROMPT_BLOCK_START}/,/${FISH_PROMPT_BLOCK_END}/d" "${config_file}"
    sed -i "/${LEGACY_FISH_PROMPT_BLOCK_START}/,/${LEGACY_FISH_PROMPT_BLOCK_END}/d" "${config_file}"
}

remove_fish_env_block() {
    local config_file="$1"

    [[ -f "${config_file}" ]] || return 0
    sed -i "/${FISH_ENV_BLOCK_START}/,/${FISH_ENV_BLOCK_END}/d" "${config_file}"
    sed -i "/${LEGACY_FISH_ENV_BLOCK_START}/,/${LEGACY_FISH_ENV_BLOCK_END}/d" "${config_file}"
    sed -i "/${LEGACY_FISH_PATH_BLOCK_START}/,/${LEGACY_FISH_PATH_BLOCK_END}/d" "${config_file}"
}

write_fish_env_block() {
    local config_file="$1"

    {
        echo "${FISH_ENV_BLOCK_START}"
        cat <<'EOF'
set -l shell_env_claude_env_file "$HOME/.config/claude-code/env.sh"
if test -f "$shell_env_claude_env_file"
    bash -lc '
        source "$1"
        while IFS= read -r name; do
            if [[ -n ${!name+x} ]]; then
                printf "%s\t%s\n" "$name" "${!name}"
            fi
        done < <(sed -nE "s/^[[:space:]]*export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/p" "$1" | sort -u)
    ' bash "$shell_env_claude_env_file" | while read -l line
        set -l pair (string split -m 1 \t -- "$line")
        if test (count $pair) -eq 2
            set -gx $pair[1] $pair[2]
        end
    end
end

if not contains -- "$HOME/.local/bin" $PATH
    set -gx PATH "$HOME/.local/bin" $PATH
end

set -gx EDITOR vim
set -gx VISUAL vim
set -gx LESSCHARSET utf-8

if type -q dircolors
    set -gx LS_COLORS (dircolors -c | string replace -r "^setenv LS_COLORS '(.*)'\$" '$1')
end

set -l shell_env_ls_colors_suffix "di=38;5;75:ln=38;5;222"
if not string match -q "*$shell_env_ls_colors_suffix*" "$LS_COLORS"
    if test -n "$LS_COLORS"
        set -gx LS_COLORS "$LS_COLORS:$shell_env_ls_colors_suffix"
    else
        set -gx LS_COLORS "$shell_env_ls_colors_suffix"
    end
end
EOF
        echo "${FISH_ENV_BLOCK_END}"
    } >>"${config_file}"
}

install_fish_env() {
    local config_dir="$HOME/.config/fish"
    local config_file="${config_dir}/config.fish"

    mkdir -p "${config_dir}"
    touch "${config_file}"
    remove_fish_env_block "${config_file}"
    write_fish_env_block "${config_file}"
    echo "fish env block installed in ${config_file}"
}

uninstall_fish_env() {
    local config_file="$HOME/.config/fish/config.fish"

    remove_fish_env_block "${config_file}"
    echo "fish env block removed from ${config_file}"
}

write_fish_prompt_block() {
    local config_file="$1"

    {
        echo "${FISH_PROMPT_BLOCK_START}"
        cat <<'EOF'
# Git Bash-style prompt: green user@host, cyan full $PWD, light orange git
# status with color hints (green branch, red dirty/untracked markers), a
# right-aligned timestamp, then the command on a new line.
set -g __fish_git_prompt_showdirtystate 1
set -g __fish_git_prompt_showuntrackedfiles 1
set -g __fish_git_prompt_color ffaf5f
set -g __fish_git_prompt_color_prefix ffaf5f
set -g __fish_git_prompt_color_suffix ffaf5f
set -g __fish_git_prompt_color_branch green
set -g __fish_git_prompt_color_branch_detached red
set -g __fish_git_prompt_color_dirtystate red
set -g __fish_git_prompt_color_stagedstate green
set -g __fish_git_prompt_color_untrackedfiles red
set -g __fish_git_prompt_color_cleanstate green

function fish_prompt --description 'shell-env: Git Bash-style prompt'
    if not set -q __fish_prompt_hostname
        set -g __fish_prompt_hostname (prompt_hostname)
    end

    set -l prompt_user "$USER"
    if test -z "$prompt_user"
        set prompt_user (id -un 2>/dev/null)
    end

    set -l suffix '$'
    switch "$prompt_user"
        case root toor
            set suffix '#'
    end

    set -l clock (printf '\e[s\e[999C\e[8D\e[38;5;139m%s\e[0m\e[u' (date +%T))

    echo -n -s (set_color 5fd787) "$prompt_user@$__fish_prompt_hostname " (set_color 5fd7ff) $PWD (set_color ffaf5f) (fish_vcs_prompt) (set_color normal) $clock
    echo
    echo -n -s (set_color -o eeeeee) "$suffix " (set_color normal)
end

function fish_title --description 'shell-env: show the working directory'
    echo $PWD
end
EOF
        echo "${FISH_PROMPT_BLOCK_END}"
    } >>"${config_file}"
}

install_fish_prompt() {
    local config_dir="$HOME/.config/fish"
    local config_file="${config_dir}/config.fish"

    mkdir -p "${config_dir}"
    touch "${config_file}"
    remove_fish_prompt_block "${config_file}"
    write_fish_prompt_block "${config_file}"
    echo "fish prompt block installed in ${config_file}"
}

uninstall_fish_prompt() {
    local config_file="$HOME/.config/fish/config.fish"

    remove_fish_prompt_block "${config_file}"
    echo "fish prompt block removed from ${config_file}"
}

remove_fish_colors_block() {
    local config_file="$1"

    [[ -f "${config_file}" ]] || return 0
    sed -i "/${FISH_COLORS_BLOCK_START}/,/${FISH_COLORS_BLOCK_END}/d" "${config_file}"
    sed -i "/${LEGACY_FISH_COLORS_BLOCK_START}/,/${LEGACY_FISH_COLORS_BLOCK_END}/d" "${config_file}"
}

write_fish_colors_block() {
    local config_file="$1"

    {
        echo "${FISH_COLORS_BLOCK_START}"
        cat <<'EOF'
# Keep editable command text at the terminal default, matching Bash after
# PS1 resets colors. Prompt, status, autosuggestion, search, and pager
# colors remain explicit for readability on dark backgrounds.
set -g fish_color_normal normal
set -g fish_color_command normal
set -g fish_color_keyword normal
set -g fish_color_quote normal
set -g fish_color_param normal
set -g fish_color_redirection normal
set -g fish_color_operator normal
set -g fish_color_end normal
set -g fish_color_option normal
set -g fish_color_escape normal
set -g fish_color_error normal
set -g fish_color_valid_path normal
set -g fish_color_comment normal
set -g fish_color_autosuggestion brblack
set -g fish_color_selection brwhite --background=brblack
set -g fish_color_search_match --background=555555
set -g fish_color_user brgreen
set -g fish_color_host brmagenta
set -g fish_color_host_remote bryellow
set -g fish_color_cwd brcyan
set -g fish_color_cwd_root ff8700
set -g fish_color_status ff8700
set -g fish_color_cancel ff8700
set -g fish_color_match bryellow --background=brblack
set -g fish_color_history_current normal
set -g fish_pager_color_completion brwhite
set -g fish_pager_color_description bryellow
set -g fish_pager_color_prefix brgreen
set -g fish_pager_color_progress brwhite --background=brblack
set -g fish_pager_color_secondary_background --background=brblack
set -g fish_pager_color_selected_background --background=brblack

set -g __fish_git_prompt_color ffaf5f
set -g __fish_git_prompt_color_prefix ffaf5f
set -g __fish_git_prompt_color_suffix ffaf5f
set -g __fish_git_prompt_color_branch green
set -g __fish_git_prompt_color_branch_detached red
set -g __fish_git_prompt_color_dirtystate red
set -g __fish_git_prompt_color_stagedstate green
set -g __fish_git_prompt_color_invalidstate red
set -g __fish_git_prompt_color_untrackedfiles red
set -g __fish_git_prompt_color_cleanstate green
set -g __fish_git_prompt_color_stashstate brblue
set -g __fish_git_prompt_color_upstream ffaf5f
set -g __fish_git_prompt_color_flags ffaf5f
EOF
        echo "${FISH_COLORS_BLOCK_END}"
    } >>"${config_file}"
}

install_fish_colors() {
    local config_dir="$HOME/.config/fish"
    local config_file="${config_dir}/config.fish"

    mkdir -p "${config_dir}"
    touch "${config_file}"
    remove_fish_colors_block "${config_file}"
    write_fish_colors_block "${config_file}"
    echo "fish color block installed in ${config_file}"
}

uninstall_fish_colors() {
    local config_file="$HOME/.config/fish/config.fish"

    remove_fish_colors_block "${config_file}"
    echo "fish color block removed from ${config_file}"
}

install_vim() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # shellcheck source=../vim_setup.sh
    source "${script_dir}/../vim_setup.sh"
    install_vim_config
}

run_mode() {
    local mode="$1"

    case "${mode}" in
        -h | --help | help)
            print_help
            ;;
        install)
            install_fish
            ;;
        env | path)
            install_fish_env
            ;;
        prompt)
            install_fish_prompt
            ;;
        colors)
            install_fish_colors
            ;;
        vim)
            install_vim
            ;;
        uninstall-env | uninstall-path)
            uninstall_fish_env
            ;;
        uninstall-prompt)
            uninstall_fish_prompt
            ;;
        uninstall-colors)
            uninstall_fish_colors
            ;;
        all | "")
            install_fish
            install_fish_env
            install_fish_prompt
            install_fish_colors
            install_vim
            ;;
        *)
            echo "Error: unknown mode '${mode}'" >&2
            print_help >&2
            return 1
            ;;
    esac
}

main() {
    if [[ $# -eq 0 ]]; then
        run_mode all
        return
    fi

    local mode status=0
    for mode in "$@"; do
        run_mode "${mode}" || status=$?
    done
    return "${status}"
}

main "$@"
