# Shell Env

This directory contains scripts to configure Bash and Vim.

## Layout

- `bash/setup.sh`: Bash environment, prompt, and Vim setup.
- `bash/git_prompt.sh`: Git prompt helper used by Bash.
- `vim_setup.sh`: shared Vim settings writer used by the Bash setup script.

The Bash setup aligns these environment variables:

- `PATH`: prepends `~/.local/bin` when it is not already present.
- `EDITOR`: set to `vim`.
- `VISUAL`: set to `vim`.
- `LS_COLORS`: uses `dircolors` when available, then sets directories to light blue (`38;5;75`) and symlinks to light orange (`38;5;222`) without bold attributes.

The Bash setup script writes a managed Vim settings block to `~/.vimrc`.

## Activate Changes

After running the setup script, you can activate the new shell settings in the
current terminal without opening a new one:

```bash
source ~/.bashrc
```

For Vim settings, reopen Vim or run `:source ~/.vimrc` inside Vim.

## Bash

Configures Bash with a managed environment block and a Git Bash-style two-line prompt (green `user@host`, teal full path, amber Git status with `__git_ps1` color hints so the dirty/untracked markers turn red when the tree is dirty, a right-aligned timestamp, then the command on a new line), plus terminal-default command input and Vim settings.

```bash
bash bash/setup.sh                     # install bash env + prompt + vim (default)
bash bash/setup.sh env                 # install env block only
bash bash/setup.sh path                # alias for env
bash bash/setup.sh prompt              # install prompt block only
bash bash/setup.sh vim                 # install vim block only
bash bash/setup.sh uninstall-env       # remove the env block
bash bash/setup.sh uninstall-path      # alias for uninstall-env
bash bash/setup.sh uninstall-prompt    # remove the prompt block
bash bash/setup.sh env prompt vim      # run multiple modes in order
```

Bash config is written to `~/.bashrc`. Prompt setup copies
`bash/git_prompt.sh` to `~/.local/git_prompt.sh`.

## Vim

Writes a managed Vim settings block to `~/.vimrc`. Shell-independent;
sourced by the Bash setup script so a Vim config is installed regardless
of which mode you run.

**Usage:**

```bash
bash vim_setup.sh           # write the vim block standalone
source vim_setup.sh         # expose install_vim_config in the current shell
```

Supported package managers: `apt-get`, `dnf`, `yum`, `apk`, `pacman`,
`zypper`, `brew`. `sudo` is used automatically when not running as root.
