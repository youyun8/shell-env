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

Env behavior:
  Adds a managed block to ~/.config/fish/config.fish that prepends
  ~/.local/bin when it is not already present in PATH, sets EDITOR and
  VISUAL to vim, and sets LS_COLORS.

Prompt behavior:
  Adds a managed block to ~/.config/fish/config.fish that defines
  fish_prompt to show user@host, the full \$PWD, git status, and
  puts the input on a new line, with the current time on the right.

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
        $sudo apt-get update
        $sudo apt-get install -y fish
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
    } >> "${config_file}"
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
# Mirror fish's default fish_prompt but show the full $PWD, put the
# input on a new line, and show the current time on the right.
# Keeps the default colors, user@host layout, and vcs/status segments untouched.
function fish_prompt --description 'shell-env: default prompt + full path + newline'
    set -l last_pipestatus $pipestatus
    set -lx __fish_last_status $status

    if not set -q __fish_prompt_hostname
        set -g __fish_prompt_hostname (prompt_hostname)
    end

    set -l prompt_user "$USER"
    if test -z "$prompt_user"
        set prompt_user (id -un 2>/dev/null)
    end

    set -l color_userhost afffaf
    set -l color_cwd ffaf87
    set -l color_git ffff87
    set -l suffix '>'
    switch "$prompt_user"
        case root toor
            set suffix '#'
    end

    set -g __fish_git_prompt_color $color_git

    set -l prompt_status (__fish_print_pipestatus " [" "]" "|" (set_color $fish_color_status) (set_color $fish_color_status) $last_pipestatus)

    echo -n -s (set_color $color_userhost) "$prompt_user@$__fish_prompt_hostname" (set_color normal) ' ' (set_color $color_cwd) $PWD (set_color $color_git) (fish_vcs_prompt) (set_color normal) $prompt_status
    echo
    echo -n -s (set_color normal) "$suffix "
end

function fish_right_prompt --description 'shell-env: current time'
    echo -n -s (set_color e4e4e4) (date '+%H:%M:%S') (set_color normal)
end
EOF
        echo "${FISH_PROMPT_BLOCK_END}"
    } >> "${config_file}"
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

# Keep the git status segment on Fish's yellow hue, color 228 / #FFFF87.
set -g __fish_git_prompt_color ffff87
set -g __fish_git_prompt_color_branch ffff87
set -g __fish_git_prompt_color_branch_detached ffff87
set -g __fish_git_prompt_color_dirtystate ffff87
set -g __fish_git_prompt_color_stagedstate ffff87
set -g __fish_git_prompt_color_invalidstate ffff87
set -g __fish_git_prompt_color_untrackedfiles ffff87
set -g __fish_git_prompt_color_cleanstate ffff87
set -g __fish_git_prompt_color_stashstate ffff87
set -g __fish_git_prompt_color_upstream ffff87
set -g __fish_git_prompt_color_flags ffff87
EOF
        echo "${FISH_COLORS_BLOCK_END}"
    } >> "${config_file}"
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
        -h|--help|help)
            print_help
            ;;
        install)
            install_fish
            ;;
        env|path)
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
        uninstall-env|uninstall-path)
            uninstall_fish_env
            ;;
        uninstall-prompt)
            uninstall_fish_prompt
            ;;
        uninstall-colors)
            uninstall_fish_colors
            ;;
        all|"")
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
