# Updating

Run <kbd>:Update</kbd> inside Neovim. It checks GitHub for a newer release, downloads it, installs it in the
background, and then asks whether to restart. Choosing **Restart now** reopens Neovim on the new version with your
windows and buffers restored. If a buffer has unsaved changes, the choice is **Save all and restart** instead.
Progress shows in the command line while it runs, and the final message links to the list of changes.

`:Update!` reinstalls the latest release even when you already have it, which repairs an install you have edited
by accident.

## What an Update Keeps

| Path                                                          | On update                                           |
| ------------------------------------------------------------- | --------------------------------------------------- |
| `config.yml`, `theme.yml`, `.vale.ini`, `.markdownlint.jsonc` | Kept as you have them; the release copy is used only when yours is missing |
| Vale style packages (`vale-styles/`)                          | Kept, so <kbd>:ValeSync</kbd> is not needed again    |
| Everything else (`init.lua`, `lua/`, `docs/`, `lazy-lock.json`) | Replaced with the release                         |

Because your copies of those four files are kept, settings that a release adds to them are not copied in. Every
setting has a built-in default, so nothing breaks, and the release notes say when a new one is worth adding.

## Rolling Back

The version you updated from is moved to `<config>.previous` (for example `~/.config/nvim.previous`), and each
update replaces it. To roll back, quit Neovim and swap the two directories:

```sh
mv ~/.config/nvim ~/.config/nvim.broken && mv ~/.config/nvim.previous ~/.config/nvim
```

## Update Check

Once a day, Neovim also checks for a new release in the background and tells you when one is available. It only
notifies you and never installs anything itself. To turn the check off, set `checkOnStartup: false` under
`updates` in `config.yml`.

## Git Checkouts

`:Update` works only on installs from a release. In a
[`git clone`](installation.md#manual-install-from-source), it refuses and asks you to run `git pull` instead.
