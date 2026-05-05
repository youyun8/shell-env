#!/bin/bash

set -e

NUSHELL_ENV_BLOCK_START="# >>> shell-env nushell-env >>>"
NUSHELL_ENV_BLOCK_END="# <<< shell-env nushell-env <<<"
LEGACY_NUSHELL_ENV_BLOCK_START="# >>> bash-env-setup nushell-env >>>"
LEGACY_NUSHELL_ENV_BLOCK_END="# <<< bash-env-setup nushell-env <<<"
NUSHELL_PROMPT_BLOCK_START="# >>> shell-env nushell-prompt >>>"
NUSHELL_PROMPT_BLOCK_END="# <<< shell-env nushell-prompt <<<"
LEGACY_NUSHELL_PROMPT_BLOCK_START="# >>> bash-env-setup nushell-prompt >>>"
LEGACY_NUSHELL_PROMPT_BLOCK_END="# <<< bash-env-setup nushell-prompt <<<"
NUSHELL_LATEST_RELEASE_API="https://api.github.com/repos/nushell/nushell/releases/latest"

print_help() {
    cat <<EOF
Usage:
  bash nushell/setup.sh                # install nushell + env + prompt + vim
  bash nushell/setup.sh install        # install nushell only
  bash nushell/setup.sh env            # install Nushell env block only
  bash nushell/setup.sh prompt         # install Nushell prompt config only
  bash nushell/setup.sh vim            # install vim config only
  bash nushell/setup.sh uninstall-env  # remove the env block
  bash nushell/setup.sh uninstall-prompt
  bash nushell/setup.sh env prompt     # run multiple modes in order
  bash nushell/setup.sh [--help|-h]

Description:
  Installs Nushell plus optional env, prompt, and Vim configuration.

Supported package managers:
  apt-get, dnf, yum, apk, pacman, zypper, brew
  On apt systems without a nushell package, installs the latest GitHub
  release tarball to /usr/local/bin.

Env behavior:
  Adds a managed block to ~/.config/nushell/env.nu that prepends
  ~/.local/bin when it is not already present in PATH, sets EDITOR and
  VISUAL to vim, and sets LS_COLORS.

Prompt behavior:
  Adds a managed block to ~/.config/nushell/config.nu that shows
  user@host, the full \$PWD, git status, and puts the input on a new line,
  with the current time on the right.
EOF
}

install_nushell() {
    if command -v nu >/dev/null 2>&1; then
        echo "nushell already installed: $(command -v nu) ($(nu --version 2>/dev/null))"
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
        echo "Installing nushell via apt-get..."
        $sudo apt-get update
        if apt-cache show nushell >/dev/null 2>&1; then
            $sudo apt-get install -y nushell
        else
            echo "nushell is not available from configured apt repositories; installing latest release from GitHub..."
            install_nushell_from_github_release "${sudo}"
        fi
    elif command -v dnf >/dev/null 2>&1; then
        echo "Installing nushell via dnf..."
        $sudo dnf install -y nushell
    elif command -v yum >/dev/null 2>&1; then
        echo "Installing nushell via yum..."
        $sudo yum install -y nushell
    elif command -v apk >/dev/null 2>&1; then
        echo "Installing nushell via apk..."
        $sudo apk add nushell
    elif command -v pacman >/dev/null 2>&1; then
        echo "Installing nushell via pacman..."
        $sudo pacman -Sy --noconfirm nushell
    elif command -v zypper >/dev/null 2>&1; then
        echo "Installing nushell via zypper..."
        $sudo zypper install -y nushell
    elif command -v brew >/dev/null 2>&1; then
        echo "Installing nushell via brew..."
        brew install nushell
    else
        echo "Error: no supported package manager found (apt-get, dnf, yum, apk, pacman, zypper, brew)." >&2
        return 1
    fi

    if ! command -v nu >/dev/null 2>&1; then
        echo "Error: nushell installation completed but 'nu' is not on PATH." >&2
        return 1
    fi

    echo "nushell installed: $(command -v nu) ($(nu --version 2>/dev/null))"
}

download_to_stdout() {
    local url="$1"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${url}"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "${url}"
    else
        echo "Error: curl or wget is required to download Nushell from GitHub." >&2
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
        echo "Error: curl or wget is required to download Nushell from GitHub." >&2
        return 1
    fi
}

ensure_nushell_downloader() {
    local sudo="$1"

    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        return 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
        echo "Installing curl for GitHub download..."
        $sudo apt-get install -y ca-certificates curl
        return 0
    fi

    echo "Error: curl or wget is required to download Nushell from GitHub." >&2
    return 1
}

nushell_linux_target() {
    case "$(uname -m)" in
        x86_64|amd64)
            echo "x86_64-unknown-linux-gnu"
            ;;
        aarch64|arm64)
            echo "aarch64-unknown-linux-gnu"
            ;;
        armv7l|armv7)
            echo "armv7-unknown-linux-gnueabihf"
            ;;
        *)
            echo "Error: unsupported Linux architecture for Nushell GitHub install: $(uname -m)" >&2
            return 1
            ;;
    esac
}

latest_nushell_version() {
    download_to_stdout "${NUSHELL_LATEST_RELEASE_API}" \
        | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' \
        | sed -n '1p'
}

install_nushell_from_github_release() {
    local sudo="$1"
    local target version archive_name download_url tmpdir archive_file extract_dir binary

    ensure_nushell_downloader "${sudo}"

    target="$(nushell_linux_target)"
    version="$(latest_nushell_version)"

    if [[ -z "${version}" ]]; then
        echo "Error: could not determine latest Nushell release version from GitHub." >&2
        return 1
    fi

    archive_name="nu-${version}-${target}.tar.gz"
    download_url="https://github.com/nushell/nushell/releases/download/${version}/${archive_name}"
    tmpdir="$(mktemp -d)"
    archive_file="${tmpdir}/${archive_name}"
    extract_dir="${tmpdir}/nu-${version}-${target}"

    download_to_file "${download_url}" "${archive_file}"
    tar -xzf "${archive_file}" -C "${tmpdir}"

    if [[ ! -x "${extract_dir}/nu" ]]; then
        echo "Error: downloaded Nushell archive did not contain an executable 'nu'." >&2
        rm -rf "${tmpdir}"
        return 1
    fi

    $sudo install -d /usr/local/bin
    for binary in "${extract_dir}"/nu*; do
        if [[ -f "${binary}" && -x "${binary}" ]]; then
            $sudo install -m 755 "${binary}" /usr/local/bin/
        fi
    done

    rm -rf "${tmpdir}"
}

remove_nushell_env_block() {
    local config_file="$1"

    [[ -f "${config_file}" ]] || return 0
    sed -i "/${NUSHELL_ENV_BLOCK_START}/,/${NUSHELL_ENV_BLOCK_END}/d" "${config_file}"
    sed -i "/${LEGACY_NUSHELL_ENV_BLOCK_START}/,/${LEGACY_NUSHELL_ENV_BLOCK_END}/d" "${config_file}"
}

write_nushell_env_block() {
    local config_file="$1"

    {
        echo "${NUSHELL_ENV_BLOCK_START}"
        cat <<'EOF'
let shell_env_claude_env_file = ($env.HOME | path join ".config" "claude-code" "env.sh")
if ($shell_env_claude_env_file | path exists) {
    let shell_env_claude_exports = (
        bash -lc '
            source "$1"
            while IFS= read -r name; do
                if [[ -n ${!name+x} ]]; then
                    printf "%s\t%s\n" "$name" "${!name}"
                fi
            done < <(sed -nE "s/^[[:space:]]*export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/p" "$1" | sort -u)
        ' bash $shell_env_claude_env_file
        | lines
        | parse "{name}\t{value}"
        | reduce -f {} {|row, acc| $acc | upsert $row.name $row.value }
    )
    if not ($shell_env_claude_exports | is-empty) {
        load-env $shell_env_claude_exports
    }
}

let shell_env_local_bin = ($env.HOME | path join ".local" "bin")
let shell_env_path = ($env.PATH? | default [])

if not ($shell_env_path | any {|entry| $entry == $shell_env_local_bin }) {
    $env.PATH = ($shell_env_path | prepend $shell_env_local_bin)
}

$env.EDITOR = "vim"
$env.VISUAL = "vim"

if (which dircolors | is-not-empty) {
    let shell_env_dircolors = (dircolors -b | lines | first | parse "LS_COLORS='{value}';")
    if ($shell_env_dircolors | is-not-empty) {
        $env.LS_COLORS = ($shell_env_dircolors | get value | first)
    }
}

let shell_env_ls_colors_suffix = "di=38;5;75:ln=38;5;222"
let shell_env_ls_colors = ($env.LS_COLORS? | default "")

if not ($shell_env_ls_colors | str contains $shell_env_ls_colors_suffix) {
    $env.LS_COLORS = if ($shell_env_ls_colors | is-empty) {
        $shell_env_ls_colors_suffix
    } else {
        $"($shell_env_ls_colors):($shell_env_ls_colors_suffix)"
    }
}
EOF
        echo "${NUSHELL_ENV_BLOCK_END}"
    } >> "${config_file}"
}

install_nushell_env() {
    local config_dir="$HOME/.config/nushell"
    local config_file="${config_dir}/env.nu"

    mkdir -p "${config_dir}"
    touch "${config_file}"
    remove_nushell_env_block "${config_file}"
    write_nushell_env_block "${config_file}"
    echo "nushell env block installed in ${config_file}"
}

uninstall_nushell_env() {
    local config_file="$HOME/.config/nushell/env.nu"

    remove_nushell_env_block "${config_file}"
    echo "nushell env block removed from ${config_file}"
}

remove_nushell_prompt_block() {
    local config_file="$1"

    [[ -f "${config_file}" ]] || return 0
    sed -i "/${NUSHELL_PROMPT_BLOCK_START}/,/${NUSHELL_PROMPT_BLOCK_END}/d" "${config_file}"
    sed -i "/${LEGACY_NUSHELL_PROMPT_BLOCK_START}/,/${LEGACY_NUSHELL_PROMPT_BLOCK_END}/d" "${config_file}"
}

write_nushell_prompt_block() {
    local config_file="$1"

    {
        echo "${NUSHELL_PROMPT_BLOCK_START}"
        cat <<'EOF'
$env.config = ($env.config? | default {} | merge {
    show_banner: true
    color_config: (($env.config.color_config? | default {}) | merge {
        shape_binary: default
        shape_block: default
        shape_bool: default
        shape_closure: default
        shape_custom: default
        shape_datetime: default
        shape_directory: default
        shape_external: default
        shape_externalarg: default
        shape_external_resolved: default
        shape_filepath: default
        shape_flag: default
        shape_float: default
        shape_glob_interpolation: default
        shape_globpattern: default
        shape_int: default
        shape_internalcall: default
        shape_keyword: default
        shape_list: default
        shape_literal: default
        shape_match_pattern: default
        shape_matching_brackets: default
        shape_nothing: default
        shape_operator: default
        shape_pipe: default
        shape_range: default
        shape_record: default
        shape_redirection: default
        shape_signature: default
        shape_string: default
        shape_string_interpolation: default
        shape_table: default
        shape_variable: default
        shape_vardecl: default
        shape_raw_string: default
    })
})

# Show user@host, the full path, git branch/status, and put input on a new line.
# `complete` captures stderr so the noisy "fatal: not a git repository" message
# stays out of the prompt when $PWD is not inside a git work tree.
def shell_env_git_prompt [] {
    if (which git | is-empty) {
        return ""
    }

    let in_repo_result = (^git rev-parse --is-inside-work-tree | complete)
    if $in_repo_result.exit_code != 0 {
        return ""
    }
    if (($in_repo_result.stdout | str trim) != "true") {
        return ""
    }

    let branch = (^git symbolic-ref --quiet --short HEAD | complete | get stdout | str trim)
    let ref = if ($branch | is-empty) {
        let short_sha = (^git rev-parse --short HEAD | complete | get stdout | str trim)
        if ($short_sha | is-empty) {
            "HEAD"
        } else {
            $"\(($short_sha)...\)"
        }
    } else {
        $branch
    }

    let status_lines = (^git status --porcelain | complete | get stdout | lines)
    let unstaged = ($status_lines | any {|line| $line =~ '^.[MDU]' })
    let staged = ($status_lines | any {|line| $line =~ '^[MADRCU]' })
    let untracked = ($status_lines | any {|line| $line =~ '^\?\?' })
    let flags = [
        (if $unstaged { "*" } else { "" })
        (if $staged { "+" } else { "" })
        (if $untracked { "%" } else { "" })
    ] | str join

    let decorated_ref = if ($flags | is-empty) {
        $ref
    } else {
        $"($ref) ($flags)"
    }

    $"(ansi { fg: '#AFD7FF' }) \(($decorated_ref)\)(ansi reset)"
}

# Light color palette tuned for WSL Ubuntu's dark purple background without
# relying on bold text. Each prompt segment uses a distinct hue so
# user/host/cwd/git/time are easy to tell apart.
def shell_env_current_user [] {
    let user_env = ($env.USER? | default "")
    if not ($user_env | is-empty) {
        return $user_env
    }
    try { ^id -un | str trim } catch { "" }
}

$env.PROMPT_COMMAND = {||
    let user = (shell_env_current_user)
    let host = (do --ignore-errors { hostname } | str trim | split row '.' | first)
    let userhost_color = (ansi { fg: '#AFFFAF' })
    let cwd_color = (ansi { fg: '#FFAF87' })
    let reset = (ansi reset)
    $"($userhost_color)($user)@($host)($reset) ($cwd_color)($env.PWD)($reset)(shell_env_git_prompt)\n"
}

$env.PROMPT_COMMAND_RIGHT = {|| $"(ansi { fg: '#E4E4E4' })(date now | format date "%H:%M:%S")(ansi reset)" }
$env.PROMPT_INDICATOR = {||
    let user = (shell_env_current_user)
    if ($user == "root" or $user == "toor") { "# " } else { "> " }
}
EOF
        echo "${NUSHELL_PROMPT_BLOCK_END}"
    } >> "${config_file}"
}

install_nushell_prompt() {
    local config_dir="$HOME/.config/nushell"
    local config_file="${config_dir}/config.nu"

    mkdir -p "${config_dir}"
    touch "${config_file}"
    remove_nushell_prompt_block "${config_file}"
    write_nushell_prompt_block "${config_file}"
    echo "nushell prompt block installed in ${config_file}"
}

uninstall_nushell_prompt() {
    local config_file="$HOME/.config/nushell/config.nu"

    remove_nushell_prompt_block "${config_file}"
    echo "nushell prompt block removed from ${config_file}"
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
            install_nushell
            ;;
        env)
            install_nushell_env
            ;;
        prompt)
            install_nushell_prompt
            ;;
        vim)
            install_vim
            ;;
        uninstall-env)
            uninstall_nushell_env
            ;;
        uninstall-prompt)
            uninstall_nushell_prompt
            ;;
        all|"")
            install_nushell
            install_nushell_env
            install_nushell_prompt
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
