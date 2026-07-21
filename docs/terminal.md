# Terminal Setup

Most of this configuration is terminal-agnostic, but one piece of styling depends on a terminal capability
that `xterm-256color` does not advertise by default: **undercurls** (wavy underlines with their own color).

Harper's grammar diagnostics are drawn as a dark-red wavy underline (see
[Code Intelligence](lsp.md#grammar-checking-harper)). Neovim also uses undercurls for spelling and for other
diagnostics. The **color** always applies, but the **wave** only renders when both of these are true:

1. the terminal can draw styled, colored underlines (recent Warp, WezTerm, kitty, Ghostty, and others can), and
2. Neovim is told the terminal can, through the `terminfo` database.

Without step 2, Neovim never emits the undercurl escape sequences, so the wave degrades to a flat underline —
which, in the default hint color, reads like a hyperlink.

## Symptom

Flagged text shows a straight underline instead of a wave, and `echo $TERM` reports `xterm-256color`. That
entry declares neither styled underlines (`Smulx`) nor colored underlines (`Setulc`).

## Fix: add the underline capabilities to `terminfo`

The following adds the two missing capabilities to the `xterm-256color` entry in your **user** terminfo
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

At a fresh shell prompt, print a red undercurl directly — this tests the terminal itself, independent of
Neovim and terminfo:

```sh
printf '\e[4:3m\e[58:2::255:0:0mwavy if supported\e[0m\n'
```

If that shows a red wave, the terminal supports undercurls. Then open a file with a spelling or grammar
mistake in Neovim: the flagged text should now carry the dark-red wave rather than a flat line.

## If it still looks flat

- **The `printf` test showed a flat line too.** The terminal itself does not render undercurls in this
  version. The dark-red color still applies and already distinguishes Harper's marks from links, so no
  further action is needed unless you upgrade or switch terminals.
- **The `printf` test waved but Neovim did not.** The terminfo entry did not take — re-run `tic -x` and
  confirm with `infocmp -x xterm-256color | grep -iE 'smulx|setulc'`, then fully restart Neovim.

## Related

- The underline color lives in `theme.yml` (`HarperDiagnosticUnderline`) — change it there; see
  [Theming](theming.md).
- Function keys (`F12`, `Shift+F12`) that appear dead are a different terminal/OS capture issue, covered in
  [Code Intelligence](lsp.md).
