# ohmagub

> A personal, phase-based setup for **Ubuntu 26.04+ (GNOME)** — my `aru.sh/setup`
> tooling, reworked for stock GNOME (no i3), driven by my own dotfiles.

`ohmagub` turns a fresh Ubuntu install into my configured workstation, in
**independently runnable phases**. It installs tooling + apps, wires up GNOME
for a tiling/9-workspace workflow, and lays my dotfiles on top.

---

## Quick start

```bash
# on a fresh Ubuntu 26.04+ machine:
wget -qO- https://raw.githubusercontent.com/arush-sal/ohmagub/master/boot.sh | bash
```

Bootstraps to `~/.local/share/ohmagub` and runs every phase. **Log out/in
afterward** for the docker group, login shell, and GNOME extensions to take
effect.

> ⚠️ **Clean your dotfiles for native Ubuntu first** (see below) — the committed
> `.zshrc`/`env.zsh` were WSL-flavored and reference mise/pyenv.

---

## Phases

Run everything, or any single phase (idempotent):

```bash
ohmagub install            # all core phases, in order
ohmagub phase languages    # just one (by name)
ohmagub phase 40           # ...or by number
ohmagub phases             # list them
ohmagub update             # git pull + re-run all
```

| # | Phase | What it does |
|---|-------|--------------|
| 00 | `preflight` | OS check (26.04+), apt components, base pkgs + `yq`, locale, timezone, GRUB, root red-prompt, links the `ohmagub` CLI |
| 10 | `shell` | zsh + oh-my-zsh + zsh-autosuggestions + fzf(junegunn), sets login shell |
| 20 | `dotfiles` | clone `arush-sal/dotfiles` → `~/Documents/dotfiles` (HTTPS→SSH remote), rsync home-mirror files, `insteadOf` rewrite |
| 30 | `cli` | `bin` (→ `~/go/bin`), tmux (gpakosz + your overlay), ripgrep, yt-dlp |
| 40 | `languages` | Go (longsleep PPA), Node (nvm), Python (system python3) |
| 50 | `dev` | Docker (get.docker.com), k8s (kubectl/helm/kubectx/kubens/k9s/kind, bin>apt>direct), gh + extensions, gcloud, Codex + Claude Code CLIs |
| 60 | `editors` | vim-gtk3 + Vundle (`:PluginInstall`, `:GoInstallBinaries`) incl. root; VS Code (bare) |
| 70 | `apps` | Chrome, Slack (snap), VLC, Deluge, tilda, GPaste + fonts |
| 80 | `gnome` | dark mode, 9 static workspaces, per-workspace app assignment, omakub extensions, `Super+1..9` keybindings, your terminal dconf |
| — | `keys` | **optional/interactive** — import SSH/GPG keys from your gists (`ohmagub phase keys`) |

---

## Your dotfiles must be cleaned for native Ubuntu

ohmagub syncs `arush-sal/dotfiles` verbatim. Before running, update them:

**`.zshrc`** — delete `eval "$(/usr/bin/mise activate zsh)"` (mise is dropped).

**`.oh-my-zsh/custom/env.zsh`**
- Replace the WSL `$PATH` (`/mnt/c/...`, `/usr/lib/wsl/...`) with a native one.
- Delete the 4 `pyenv` lines (Python is system `python3` now).
- `export MAIL="/var/mail/$USER"` (was a stale username).
- Fix the quoted-tilde bug: `[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"`.

The terminal profile (`gnome/gnome-terminal-profiles.dconf`) is loaded **as-is** —
the `su` custom-command is intentional (password-locks terminal access; you live
in tmux).

---

## Customize — `config.sh`

One file. Highlights: `OHMAGUB_WORKSPACES`, `OHMAGUB_WORKSPACE_APPS` (the WS→app
map), `OHMAGUB_GNOME_EXTENSIONS`, `OHMAGUB_DESKTOP_APPS`, `OHMAGUB_K8S_TOOLS`,
`OHMAGUB_GH_EXTENSIONS`, `OHMAGUB_NODE_VERSION`, `OHMAGUB_INSTALL_*` flags,
`OHMAGUB_DOTFILES_EXCLUDE`. Machine-local, un-committed overrides → `config.local.sh`.

---

## Workspaces & keys

9 static workspaces. Default app-per-workspace: 1=terminal, 2=chrome, 3=slack,
4=vscode, 5=nautilus, 9=deluge (Auto Move Windows).

| Keys | Action |
|---|---|
| `Super`+`1..9` | Switch workspace |
| `Super`+`Shift`+`1..9` | Move window to workspace |
| `Super`+`Return` | Terminal · `Super`+`e` Files |
| `Super`+`Shift`+`q` | Close · `Super`+`f` Fullscreen |
| `Super`+`T` | Tactile tiling grid |

---

## Notes

- Target **Ubuntu 26.04+ / GNOME 48+**. Third-party extensions may lag EGO
  builds on a brand-new GNOME; ohmagub warns and continues.
- Idempotent — re-running skips what's present.
- Secrets never touch the repo; `ohmagub phase keys` is opt-in and interactive.
- Built on Windows; **test in an Ubuntu VM first** before your daily driver.

---

Inspired by [Omakub](https://omakub.org). Made mine.
