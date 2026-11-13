# nest-veil

Keep separate logins and configs for each client or project on one Linux
machine, and switch between them by changing directory.

Inside `~/dev/acme`, `claude`, `gh`, `git`, VS Code and your browser use the
Acme logins. Step into `~/dev/acme/globex` and you're in the Globex workspace,
which shares Acme's logins unless you give it its own. Leave, and you're back
to your private setup.

```sh
cd ~/dev/acme
nest-veil new acme
nest-veil set acme .              # prompt now shows "acme"
nest-veil new globex
nest-veil set globex ./globex     # nested in acme, because ./globex is inside ~/dev/acme
```

## What a workspace separates

| Program | How |
|---|---|
| Claude Code | its own `CLAUDE_CONFIG_DIR` |
| GitHub CLI | its own `GH_CONFIG_DIR` |
| git | its own `GIT_CONFIG_GLOBAL`, stacked on top of the parent's and `~/.gitconfig` |
| VS Code (`code`, `code-oss`, `codium`) | its own `--user-data-dir` and `--extensions-dir`: a separate instance |
| Browsers (Brave, Chrome, Chromium, Edge, Vivaldi, Opera, Firefox, LibreWolf, Zen) | a separate profile per browser: a separate instance with its own logins |
| Anything configured by an environment variable | one line in the workspace's `env` file |

Inside a workspace, plain `code`, `brave`, `firefox`, ... open that
workspace's instance, so links and "open in VS Code" land in the right place.

## Commands

```
nest-veil                       show the active workspace and list all workspaces
nest-veil new <name>            create a workspace
nest-veil set <name> <dir>      auto-enable <name> in <dir> and its subdirectories
nest-veil unset <dir>           stop auto-enabling a workspace in <dir>
nest-veil <name> <cmd> [args]   run <cmd> in workspace <name>, from anywhere
nest-veil <name>                start a shell in workspace <name>
nest-veil off [cmd] [args]      run <cmd> (or a shell) outside any workspace
```

Setting a directory that already belongs to another workspace moves it. When
directories overlap, the most specific one wins. A workspace you start
yourself (`nest-veil <name>`) stays on when you change directory.

## Nesting

A workspace is nested in another when its directory is inside the other's
directory. A nested workspace:

- **shares its parent's logins** (`claude/`, `gh/`, `vscode/`, `browsers/<browser>`)
  until it has its own. Login folders are created on first use in the top-most
  workspace, so sharing is the default. To split one off, create the folder,
  e.g. `mkdir -p ~/.config/nest-veil/globex/claude`.
- **stacks its `env`** on top of the parent's.
- **stacks its `gitconfig`** on top of the parent's: nest-veil keeps an include
  block at the top of each workspace's `gitconfig` pointing at the parent's
  (or `~/.gitconfig`). `git config --global` inside a workspace writes to that
  workspace's own file.

`nest-veil` shows the tree and what each nested workspace shares.

## Files

Everything lives in `~/.config/nest-veil/<name>/` (or `$NEST_VEIL_HOME`):

```
claude/  gh/  vscode/  browsers/   logins, created on first use
gitconfig                          git config for this workspace
env                                extra variables, KEY=VALUE per line
dirs                               directories, managed by set/unset
parent                             optional: force a parent workspace by name
```

`env` example. `$NEST_VEIL_DIR` is that workspace's folder; `$HOME` and `~` expand:

```sh
NEST_VEIL_COLOR=cyan                 # prompt marker colour
AWS_PROFILE=acme
KUBECONFIG=$NEST_VEIL_DIR/kube/config
AZURE_CONFIG_DIR=$NEST_VEIL_DIR/azure
GIT_SSH_COMMAND=ssh -i ~/.ssh/id_acme -o IdentitiesOnly=yes
```

Inside a workspace, `$NEST_VEIL` is its name and `$NEST_VEIL_LABEL` its path
in the tree (`acme/globex`), for use in your own prompt or scripts.

## Shell support

Switching by directory, the prompt marker and completions are for
[fish](https://fishshell.com). Everything else (`nest-veil <name> <cmd>`,
`new`, `set`, `unset`, `off`) works from any shell.

## Install

On Arch Linux and derivatives (CachyOS, EndeavourOS, Manjaro…), the package
recipe lives in this repository under `packaging/aur/`. It isn't on the AUR
yet, but [paru](https://github.com/Morganamilo/paru) can use this repository
the same way. Add these lines to the end of your paru config
(`~/.config/paru/paru.conf` if you have one, otherwise `/etc/paru.conf`):

```ini
[nest-veil]
Url = https://github.com/Exouxas/nest-veil
Path = packaging/aur
```

Then install it:

```sh
paru -Sy --pkgbuilds                       # fetch the recipe
paru -S nest-veil-git
```

It builds the latest commit, and paru updates it with the rest of the system
whenever there is a new commit (`paru -Syu --devel`, or just `paru` if `Devel`
is on in your config). Open a new terminal afterwards.

Without paru, build the package once by hand. It won't update by itself:

```sh
git clone https://github.com/Exouxas/nest-veil
cd nest-veil/packaging/aur/nest-veil-git
makepkg -si
```

## Tests

```sh
tests/run.sh
```

They use a throwaway config folder and fake programs, so they never touch
your real workspaces.

## License

MIT
