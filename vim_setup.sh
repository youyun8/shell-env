#!/bin/bash

VIM_BLOCK_START="\" >>> shell-env vim >>>"
VIM_BLOCK_END="\" <<< shell-env vim <<<"
LEGACY_VIM_BLOCK_START="\" >>> bash-env-setup vim >>>"
LEGACY_VIM_BLOCK_END="\" <<< bash-env-setup vim <<<"

vim_print_help() {
    cat <<EOF
Usage:
  bash vim_setup.sh [--help|-h]
  source vim_setup.sh   # to expose install_vim_config in current shell

Description:
  Writes a managed Vim settings block to ~/.vimrc. Shell-independent;
  used by bash/setup.sh, fish/setup.sh, and nushell/setup.sh.
EOF
}

remove_vim_block() {
    local config_file="$1"
    local output_file="$2"

    if [[ ! -f "${config_file}" ]]; then
        : > "${output_file}"
        return 0
    fi

    awk \
        -v start="${VIM_BLOCK_START}" \
        -v end="${VIM_BLOCK_END}" \
        -v legacy_start="${LEGACY_VIM_BLOCK_START}" \
        -v legacy_end="${LEGACY_VIM_BLOCK_END}" '
        $0 == start || $0 == legacy_start { skip = 1; next }
        $0 == end || $0 == legacy_end { skip = 0; next }
        !skip { print }
    ' "${config_file}" > "${output_file}"
}

write_vim_block() {
    local config_file="$1"

    {
        echo "${VIM_BLOCK_START}"
        cat <<'EOF'
set nu
set cursorline
set tabstop=4
set shiftwidth=4
set t_Co=256

" Color configuration tuned for WSL Ubuntu's dark terminal palette.
set background=dark
hi Normal ctermfg=White ctermbg=NONE
hi LineNr cterm=bold ctermfg=LightGrey ctermbg=NONE
hi CursorLineNr cterm=bold ctermfg=LightGreen ctermbg=NONE
hi CursorLine cterm=NONE ctermbg=236

highlight DiffAdd    cterm=bold ctermfg=Black ctermbg=LightGreen gui=none
highlight DiffDelete cterm=bold ctermfg=White ctermbg=DarkRed gui=none
highlight DiffChange cterm=bold ctermfg=Black ctermbg=LightYellow gui=none
highlight DiffText   cterm=bold ctermfg=Black ctermbg=Yellow gui=none

set encoding=utf-8
set fileencodings=utf-8,latin1
set termencoding=utf-8
EOF
        echo "${VIM_BLOCK_END}"
    } >> "${config_file}"
}

acquire_vim_lock() {
    local lock_dir="$1"
    local wait_seconds=0

    while ! mkdir "${lock_dir}" 2>/dev/null; do
        ((wait_seconds++))
        if (( wait_seconds >= 30 )); then
            echo "Error: timed out waiting for Vim config lock at ${lock_dir}" >&2
            return 1
        fi
        sleep 1
    done
}

install_vim_config() {
    local vimrc lock_dir temp_file status

    vimrc="$HOME/.vimrc"
    lock_dir="${vimrc}.shell-env.lock"
    temp_file="$(mktemp "${vimrc}.XXXXXX.tmp")"

    acquire_vim_lock "${lock_dir}" || return 1

    status=0

    if ! remove_vim_block "${vimrc}" "${temp_file}"; then
        status=1
    elif ! write_vim_block "${temp_file}"; then
        status=1
    elif ! mv "${temp_file}" "${vimrc}"; then
        status=1
    else
        echo "vim block installed in ${vimrc}"
    fi

    rm -f "${temp_file}"
    rmdir "${lock_dir}" 2>/dev/null
    return "${status}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        -h|--help|help)
            vim_print_help
            exit 0
            ;;
        "")
            install_vim_config
            ;;
        *)
            echo "Error: unknown mode '${1}'" >&2
            vim_print_help >&2
            exit 1
            ;;
    esac
fi
