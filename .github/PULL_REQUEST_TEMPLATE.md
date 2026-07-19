<!-- Thanks for contributing! See CONTRIBUTING.md for the full workflow. -->
<!-- markdownlint-disable-next-line MD041 -- PR templates conventionally start at h2, not h1 -->
## Summary

<!-- What does this change, and why? Link related issues with "Closes #123". -->

## Checklist

- [ ] `scripts/check.sh` passes locally (lint, both test suites, and the missing-binary guard path)
- [ ] Commits follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, …)
- [ ] New or changed user commands and global keymaps are covered by integration specs
- [ ] New global keymaps are added to the Global Keymap Registry (`.claude/instructions/config.md`) and survive
      the terminal (see the mouse/terminal caveat there)
- [ ] Plugin changes include the matching `lazy-lock.json` update, fetched with `task install` — not `:Lazy sync`
- [ ] User-facing behavior changes are documented under `docs/`
