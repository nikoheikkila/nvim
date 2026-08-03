# File Explorer

<kbd>Space e</kbd> toggles a file tree sidebar on the right. The tree follows the file you are editing and supports the
mouse (double-click opens files and expands/collapses directories; the wheel scrolls).

Inside the tree:

| Key                                | Action                                                                                             |
| ----------------------------------- | --------------------------------------------------------------------------------------------------- |
| <kbd>j</kbd>/<kbd>k</kbd>, <kbd>Up</kbd>/<kbd>Down</kbd> | Move between entries                                                          |
| <kbd>Enter</kbd>                    | Open file / expand or collapse directory                                                            |
| <kbd>l</kbd>, <kbd>Right</kbd>      | Open file / expand directory                                                                        |
| <kbd>h</kbd>, <kbd>Left</kbd>       | Collapse directory                                                                                   |
| <kbd>d</kbd>                        | Delete — press <kbd>y</kbd> to confirm, <kbd>n</kbd> or <kbd>Esc</kbd> to abort                     |
| <kbd>r</kbd>                        | Rename (prompt pre-filled with the current name)                                                    |
| <kbd>n</kbd>                        | New file at a typed path (`sub/dir/file.md` creates the parents; trailing `/` creates a directory)  |
| <kbd>N</kbd>                        | New directory                                                                                        |
| <kbd>m</kbd>                        | Move to another path                                                                                 |
| <kbd>v</kbd> or <kbd>V</kbd>        | Visual mode — select multiple entries with <kbd>j</kbd>/<kbd>k</kbd> or mouse drag                  |
| <kbd>/</kbd>                        | Fuzzy filter within the tree                                                                         |
| <kbd>?</kbd>                        | Show all mappings                                                                                    |

With a visual selection active: <kbd>d</kbd> deletes all selected entries after a single confirmation,
<kbd>x</kbd> cuts and <kbd>p</kbd> pastes them into a target directory (bulk move), <kbd>y</kbd> + <kbd>p</kbd>
copies them.
