# File Explorer

`Space e` toggles a file tree sidebar on the right. The tree follows the file you are editing and supports the
mouse (double-click opens files and expands/collapses directories; the wheel scrolls).

Inside the tree:

| Key                  | Action                                                                                               |
| -------------------- | ---------------------------------------------------------------------------------------------------- |
| `j`/`k`, `Up`/`Down` | Move between entries                                                                                 |
| `Enter`              | Open file / expand or collapse directory                                                             |
| `l`, `Right`         | Open file / expand directory                                                                         |
| `h`, `Left`          | Collapse directory                                                                                   |
| `d`                  | Delete — press `y` to confirm, `n` or `Esc` to abort                                                 |
| `r`                  | Rename (prompt pre-filled with the current name)                                                     |
| `n`                  | New file at a typed path (`sub/dir/file.md` creates the parents; a trailing `/` creates a directory) |
| `N`                  | New directory                                                                                        |
| `m`                  | Move to another path                                                                                 |
| `v` or `V`           | Visual mode — select multiple entries with `j`/`k` or mouse drag                                     |
| `/`                  | Fuzzy filter within the tree                                                                         |
| `?`                  | Show all mappings                                                                                    |

With a visual selection active: `d` deletes all selected entries after a single confirmation, `x` cuts and `p`
pastes them into a target directory (bulk move), `y` + `p` copies them.
