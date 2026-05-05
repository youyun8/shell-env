# Shell Env

This directory contains scripts to configure Bash, Fish, Nushell, and Vim.

## Layout

- `bash/setup.sh`: Bash environment, prompt, and Vim setup.
- `bash/git_prompt.sh`: Git prompt helper used by Bash.
- `fish/setup.sh`: Fish installation, environment, prompt, colors, and Vim setup.
- `nushell/setup.sh`: Nushell installation, environment, prompt, and Vim setup.
- `vim_setup.sh`: shared Vim settings writer used by all shell setup scripts.

Each shell setup aligns these environment variables:

- `PATH`: prepends `~/.local/bin` when it is not already present.
- `EDITOR`: set to `vim`.
- `VISUAL`: set to `vim`.
- `LS_COLORS`: uses `dircolors` when available, then sets directories to light blue (`38;5;75`) and symlinks to light orange (`38;5;222`) without bold attributes.

All shell setup scripts write the same managed Vim settings block to `~/.vimrc`.

## Activate Changes

After running a setup script, you can activate the new shell settings in the
current terminal without opening a new one:

```bash
source ~/.bashrc
```

```fish
source ~/.config/fish/config.fish
```

```nu
source ~/.config/nushell/env.nu
```

For Vim settings, reopen Vim or run `:source ~/.vimrc` inside Vim.

## Bash

Configures Bash with a managed environment block, a prompt that shows the full path, Git status, right-side time, and terminal-default command input, plus Vim settings.

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

## Fish

Installs [fish](https://fishshell.com/) and can write managed environment, prompt, color, and Vim configuration blocks. The prompt shows the full path, Git status, and right-side time; editable command syntax uses the terminal default to match Bash.

```bash
bash fish/setup.sh                     # install fish + env + prompt + colors + vim (default)
bash fish/setup.sh install             # install fish only
bash fish/setup.sh env                 # install env block only
bash fish/setup.sh path                # alias for env
bash fish/setup.sh prompt              # install prompt block only
bash fish/setup.sh colors              # install color overrides only
bash fish/setup.sh vim                 # install vim block only
bash fish/setup.sh uninstall-env       # remove the env block
bash fish/setup.sh uninstall-path      # alias for uninstall-env
bash fish/setup.sh uninstall-prompt    # remove the prompt block
bash fish/setup.sh uninstall-colors    # remove the color block
bash fish/setup.sh env prompt colors   # run multiple modes in order
```

Fish config is written to `~/.config/fish/config.fish`.

## Nushell

Installs [Nushell](https://www.nushell.sh/) and can write managed environment, prompt, and Vim configuration. The prompt shows the full path, Git status, and right-side time; editable command syntax uses the terminal default to match Bash.
On apt-based systems where `nushell` is not available from the configured repositories, the installer downloads the latest official Linux release from GitHub and installs `nu` and its bundled plugins to `/usr/local/bin`.

```bash
bash nushell/setup.sh                  # install nushell + env + prompt + vim (default)
bash nushell/setup.sh install          # install nushell only
bash nushell/setup.sh env              # install env block only
bash nushell/setup.sh prompt           # install prompt block only
bash nushell/setup.sh vim              # install vim block only
bash nushell/setup.sh uninstall-env    # remove the env block
bash nushell/setup.sh uninstall-prompt # remove the prompt block
bash nushell/setup.sh env prompt       # run multiple modes in order
```

Nushell env config is written to `~/.config/nushell/env.nu`; prompt config is written to `~/.config/nushell/config.nu`.

## Vim

Writes a managed Vim settings block to `~/.vimrc`. Shell-independent;
sourced by all shell setup scripts so a Vim config is installed regardless
of which setup script you run.

**Usage:**

```bash
bash vim_setup.sh           # write the vim block standalone
source vim_setup.sh         # expose install_vim_config in the current shell
```

Supported package managers: `apt-get`, `dnf`, `yum`, `apk`, `pacman`,
`zypper`, `brew`. `sudo` is used automatically when not running as root.
