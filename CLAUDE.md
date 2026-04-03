# Dotfiles

This repo uses **GNU Stow** to manage symlinks from `~/dotfiles/.config/` into `~/.config/`.

- The stow directory is `~/dotfiles`, target is `~` (home)
- Running `stow .` from `~/dotfiles/` creates symlinks for everything under `.config/`
- `.stow-local-ignore` excludes: `.git`, `appimages`, `pyenvs`, `scripts`, `res`, `init.sh`, `.env`
- `scripts/` is excluded from stow but deployed separately (runtime scripts live in `scripts/runtime/`)
- Config files that are **generated at runtime** (e.g., cava config, matugen color outputs) should not be added to the repo

When adding new config directories, place them under `.config/` and re-run `stow .` to create the symlinks.
