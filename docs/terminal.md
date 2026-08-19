# Terminal Setup

Most of this configuration is terminal-agnostic, but one piece of styling depends on a terminal capability
that `xterm-256color` does not advertise by default: wavy underlines with their own color.

The two prose checkers draw wavy underlines in their own colours — Harper's grammar diagnostics in dark red,
Vale's style ones in violet (see [Code Intelligence](lsp.md#grammar-checking-harper)). Neovim also uses
underlines for spelling and for other diagnostics. The **colour** always applies, but the **wave** only
renders when both of these are true:

1. the terminal can draw styled, coloured underlines (recent Warp, WezTerm, kitty, Ghostty, and others can), and
2. Neovim is told the terminal can, through the `terminfo` database.

Without step 2, Neovim never emits the wavy underline escape sequences, so the wave degrades to a flat underline —
which, in the default hint colour, reads like a hyperlink.

## Symptom

Flagged text shows a straight underline instead of a wave, and `echo $TERM` reports `xterm-256color`. That
entry declares neither styled underlines (`Smulx`) nor colored underlines (`Setulc`).

## Fix: Add the Underline Capabilities to Terminal Information

The following adds the two missing capabilities to the `xterm-256color` entry in your **user** term info
database (`~/.terminfo`, no root required). It keeps the entry name `xterm-256color`, so remote `ssh`
sessions — which inherit `$TERM` — still name an entry every host recognizes; nothing else changes.

1. Save this as `undercurl.terminfo`:

   ```text
   xterm-256color|xterm-256color with undercurl support,
       Smulx=\E[4\:%p1%dm,
       Setulc=\E[58\:2\:\:%p1%{65536}%/%d\:%p2%{256}%/%d\:%p3%d%;m,
       use=xterm-256color,
   ```

2. Compile it (the `-x` flag keeps the extended `Smulx`/`Setulc` capabilities):

   ```sh
   tic -x undercurl.terminfo
   ```

3. Restart the terminal (and Neovim). No `$TERM` change and no shell-config edit are needed — the recompiled
   `~/.terminfo` entry takes precedence over the system one automatically.

## Verify

At a fresh shell prompt, print a red wavy underline directly — this tests the terminal itself, independent of
Neovim and term info:

```sh
printf '\e[4:3m\e[58:2::255:0:0mwavy if supported\e[0m\n'
```

If that shows a red wave, the terminal supports wavy underlines. Then open a file with a spelling or grammar
mistake in Neovim: the flagged text should now carry the dark-red wave rather than a flatline.

## If It Still Looks Flat

- **The `printf` test showed a flatline too.** The terminal itself does not render wavy underlines in this
  version. The colours still apply and already distinguish Harper's and Vale's marks from links and from each
  other, so no further action is needed unless you upgrade or switch terminals.
- **The `printf` test waved but Neovim did not.** The term info entry did not take — rerun `tic -x` and
  confirm with `infocmp -x xterm-256color | grep -iE 'smulx|setulc'`, then fully restart Neovim.

## Related

- The underline colours live in `theme.yml` (`HarperDiagnosticUnderline`, `ValeDiagnosticUnderline`) — change
  them there; see [Theming](theming.md).
- Function keys (<kbd>F12</kbd>, <kbd>Shift+F12</kbd>) that appear dead are a
  different terminal or operating system capture issue, covered in
  [Code Intelligence](lsp.md).
