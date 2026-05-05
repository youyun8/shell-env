#!/bin/bash

set -e

print_help() {
    cat <<EOF
Usage:
  bash bash/setup.sh                  # install bash env + prompt + vim
  bash bash/setup.sh env              # install Bash env block only
  bash bash/setup.sh path             # alias for env
  bash bash/setup.sh prompt           # install Bash prompt config only
  bash bash/setup.sh vim              # install vim config only
  bash bash/setup.sh uninstall-env    # remove the env block
  bash bash/setup.sh uninstall-path   # alias for uninstall-env
  bash bash/setup.sh uninstall-prompt
  bash bash/setup.sh env prompt vim   # run multiple modes in order
  bash bash/setup.sh [--help|-h]

Description:
  Installs managed Bash environment, prompt, and Vim configuration.

Env behavior:
  Adds a managed block to ~/.bashrc that prepends ~/.local/bin when it is
  not already present in PATH, sets EDITOR and VISUAL to vim, and sets
  LS_COLORS.

Prompt behavior:
  Adds a managed block to ~/.bashrc that shows user@host, the full \$PWD,
  git status, and puts the input on a new line, with the current time on
  the right.
EOF
}

BASH_ENV_BLOCK_START="# >>> shell-env bash-env >>>"
BASH_ENV_BLOCK_END="# <<< shell-env bash-env <<<"
LEGACY_BASH_ENV_BLOCK_START="# >>> bash-env-setup bash-env >>>"
LEGACY_BASH_ENV_BLOCK_END="# <<< bash-env-setup bash-env <<<"
LEGACY_PATH_BLOCK_START="# >>> bash-env-setup path >>>"
LEGACY_PATH_BLOCK_END="# <<< bash-env-setup path <<<"
PROMPT_BLOCK_START="# >>> shell-env bash-prompt >>>"
PROMPT_BLOCK_END="# <<< shell-env bash-prompt <<<"
LEGACY_PROMPT_BLOCK_START="# >>> bash-env-setup prompt >>>"
LEGACY_PROMPT_BLOCK_END="# <<< bash-env-setup prompt <<<"

remove_env_block() {
    local config_file="$1"

    [[ -f "${config_file}" ]] || return 0
    sed -i "/${BASH_ENV_BLOCK_START}/,/${BASH_ENV_BLOCK_END}/d" "${config_file}"
    sed -i "/${LEGACY_BASH_ENV_BLOCK_START}/,/${LEGACY_BASH_ENV_BLOCK_END}/d" "${config_file}"
    sed -i "/${LEGACY_PATH_BLOCK_START}/,/${LEGACY_PATH_BLOCK_END}/d" "${config_file}"
}

write_env_block() {
    local config_file="$1"

    {
        echo "${BASH_ENV_BLOCK_START}"
        cat <<'EOF'
case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *)
        export PATH="${HOME}/.local/bin${PATH:+:${PATH}}"
        ;;
esac

export EDITOR="vim"
export VISUAL="vim"

if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b)"
fi

case ":${LS_COLORS:-}:" in
    *":di=38;5;75:ln=38;5;222:"*) ;;
    *)
        export LS_COLORS="${LS_COLORS:+${LS_COLORS}:}di=38;5;75:ln=38;5;222"
        ;;
esac
EOF
        echo "${BASH_ENV_BLOCK_END}"
    } >> "${config_file}"
}

remove_prompt_block() {
    local config_file="$1"

    [[ -f "${config_file}" ]] || return 0
    sed -i "/${PROMPT_BLOCK_START}/,/${PROMPT_BLOCK_END}/d" "${config_file}"
    sed -i "/${LEGACY_PROMPT_BLOCK_START}/,/${LEGACY_PROMPT_BLOCK_END}/d" "${config_file}"
}

remove_legacy_prompt_config() {
    local config_file="$1"
    local prompt_file="$2"

    [[ -f "${config_file}" ]] || return 0
    sed -i "\|source \"${prompt_file}\"|d" "${config_file}"
    sed -i '/^# set PS1$/d' "${config_file}"
    sed -i '/^GIT_PS1_SHOWDIRTYSTATE=/d' "${config_file}"
    sed -i '/^export GIT_PS1_SHOWDIRTYSTATE=/d' "${config_file}"
    sed -i '/^GIT_PS1_SHOWUNTRACKEDFILES=/d' "${config_file}"
    sed -i '/^export GIT_PS1_SHOWUNTRACKEDFILES=/d' "${config_file}"
    sed -i '/^PS1=.*__git_ps1/d' "${config_file}"
    sed -i '/^export PS1=.*__git_ps1/d' "${config_file}"
    sed -i '/^PROMPT_COMMAND=bash_env_setup_prompt_command$/d' "${config_file}"
    sed -i '/^PROMPT_COMMAND=shell_env_prompt_command$/d' "${config_file}"
}

write_prompt_block() {
    local config_file="$1"
    local prompt_file="$2"
    local host_token="$3"

    {
        echo "${PROMPT_BLOCK_START}"
        printf 'if [ -f %q ]; then\n' "${prompt_file}"
        printf '    source %q\n' "${prompt_file}"
        cat <<EOF
    export GIT_PS1_SHOWDIRTYSTATE=1
    export GIT_PS1_SHOWUNTRACKEDFILES=1

    shell_env_prompt_command() {
        local last_status=\$?
        local chroot=""
        local title=""

        if [ -n "\${debian_chroot:-}" ]; then
            chroot="(\${debian_chroot}) "
        fi

        case "\$TERM" in
            xterm*|rxvt*)
                title='\\[\\e]0;\\u@${host_token}: \\w\\a\\]'
                ;;
        esac

        # Distinct light hues chosen for legibility on WSL Ubuntu's dark
        # purple background without relying on bold text.
        local userhost='\\[\\e[38;5;157m\\]\\u@${host_token}\\[\\e[0m\\]'
        local cwd='\\[\\e[38;5;216m\\]\\w\\[\\e[0m\\]'
        local git='\\[\\e[38;5;228m\\]'
        local time_color='\\[\\e[38;5;254m\\]'
        local reset='\\[\\e[0m\\]'
        local right_time
        local right_prompt

        right_time="\$(date +%H:%M:%S)"
        right_prompt="\\[\\e[s\\]\\[\\e[999C\\]\\[\\e[8D\\]\${time_color}\${right_time}\${reset}\\[\\e[u\\]"

        __git_ps1 "\${title}\${chroot}\${userhost} \${cwd}\${git}" "\${reset}\${right_prompt}\n\${reset}\\\\\\$ "
        return \$last_status
    }

    case ";\${PROMPT_COMMAND:-};" in
        *";shell_env_prompt_command;"*) ;;
        *)
            PROMPT_COMMAND="shell_env_prompt_command\${PROMPT_COMMAND:+;\${PROMPT_COMMAND}}"
            ;;
    esac
fi
${PROMPT_BLOCK_END}
EOF
    } >> "${config_file}"
}

install_prompt() {
    local config_file="$1"
    local prompt_file="$2"
    local host_token="$3"

    remove_prompt_block "${config_file}"
    remove_legacy_prompt_config "${config_file}" "${prompt_file}"
    write_prompt_block "${config_file}" "${prompt_file}" "${host_token}"
}

install_env() {
    local config_file="$1"

    remove_env_block "${config_file}"
    write_env_block "${config_file}"
}

copy_git_prompt() {
    local source_dir="$1"
    local target_dir="$2"

    mkdir -p "${target_dir}"

    if [[ -f "${source_dir}/git_prompt.sh" ]]; then
        cp "${source_dir}/git_prompt.sh" "${target_dir}/git_prompt.sh"
        return 0
    fi

    echo "Warning: git_prompt.sh not found in ${source_dir}"
    return 1
}

install_bash_env() {
    touch "$HOME/.bashrc"
    install_env "$HOME/.bashrc"
    echo "bash env block installed in $HOME/.bashrc"
}

uninstall_bash_env() {
    remove_env_block "$HOME/.bashrc"
    echo "bash env block removed from $HOME/.bashrc"
}

install_bash_prompt() {
    local script_dir local_dir prompt_file

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local_dir="$HOME/.local"
    prompt_file="${local_dir}/git_prompt.sh"

    copy_git_prompt "${script_dir}" "${local_dir}" || return 1

    touch "$HOME/.bashrc"
    install_prompt "$HOME/.bashrc" "${prompt_file}" '\h'
    echo "bash prompt block installed in $HOME/.bashrc"
}

uninstall_bash_prompt() {
    remove_prompt_block "$HOME/.bashrc"
    remove_legacy_prompt_config "$HOME/.bashrc" "$HOME/.local/git_prompt.sh"
    echo "bash prompt block removed from $HOME/.bashrc"
}

install_vim() {
    local script_dir

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # shellcheck source=../vim_setup.sh
    source "${script_dir}/../vim_setup.sh"
    install_vim_config
}

install_all() {
    install_bash_env
    install_bash_prompt
    install_vim
}

run_mode() {
    local mode="$1"

    case "${mode}" in
        -h|--help|help)
            print_help
            ;;
        env|path)
            install_bash_env
            ;;
        prompt)
            install_bash_prompt
            ;;
        vim)
            install_vim
            ;;
        uninstall-env|uninstall-path)
            uninstall_bash_env
            ;;
        uninstall-prompt)
            uninstall_bash_prompt
            ;;
        all|"")
            install_all
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
