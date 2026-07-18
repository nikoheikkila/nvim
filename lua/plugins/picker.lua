local search_utils = require("lib.search_utils")

local SKIP_DIRS = {
  [".git"] = true,
  ["node_modules"] = true,
  [".venv"] = true,
  ["venv"] = true,
}

local MAX_FILE_BYTES = 1024 * 1024 -- skip files bigger than 1 MiB to bound worst-case latency

-- Walk `cwd` recursively (skipping SKIP_DIRS) and collect one picker item per
-- matching line. Only used when `rg` is unavailable, so this is deliberately
-- a single, one-shot walk rather than a re-walk-on-every-keystroke design.
local function collect_matches(cwd, term)
  local items = {}

  for name, kind in
    vim.fs.dir(cwd, {
      depth = math.huge,
      skip = function(dirname)
        return not SKIP_DIRS[vim.fs.basename(dirname)]
      end,
    })
  do
    if kind == "file" then
      local path = cwd .. "/" .. name
      local stat = vim.uv.fs_stat(path)
      if stat and stat.size <= MAX_FILE_BYTES then
        local ok, lines = pcall(vim.fn.readfile, path)
        if ok then
          for lnum, line in ipairs(lines) do
            if search_utils.matches(line, term) then
              items[#items + 1] = {
                file = name,
                cwd = cwd,
                text = ("%s:%d: %s"):format(name, lnum, line),
                line = line,
                pos = { lnum, 0 },
              }
            end
          end
        end
      end
    end
  end

  return items
end

-- Fallback used when `rg` is not on PATH: prompt once for a search term, walk
-- the project a single time, then open a static-item picker with the results.
local function native_grep(cwd)
  vim.ui.input({ prompt = "Search: " }, function(term)
    if not term or term == "" then
      return
    end

    local items = collect_matches(cwd, term)
    if #items == 0 then
      vim.notify(("No matches for %q"):format(term), vim.log.levels.INFO)
      return
    end

    require("snacks").picker.pick({
      items = items,
      format = "file",
      title = ("Grep (no rg): %s"):format(term),
      cwd = cwd,
    })
  end)
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader><leader>",
        function()
          -- hidden = true surfaces dotfiles/dot-dirs; .gitignore stays honoured
          -- (ignored defaults to false) and .git/ is always excluded by snacks.
          require("snacks").picker.files({ cwd = vim.fs.root(0, { ".git" }), hidden = true })
        end,
        desc = "Find Files (Project)",
      },
      {
        "<leader>.",
        function()
          local cwd = vim.fs.root(0, { ".git" })

          if vim.fn.executable("rg") == 1 then
            require("snacks").picker.grep({ cwd = cwd, hidden = true })
            return
          end

          vim.notify("rg not found on PATH, falling back to native Lua search", vim.log.levels.WARN)
          native_grep(cwd or vim.uv.cwd())
        end,
        desc = "Grep Project (Text Search)",
      },
    },
    opts = {
      -- Only the fuzzy file picker is wanted. Every other snacks.nvim module
      -- (dashboard, notifier, zen, terminal, explorer, ...) is opt-in by
      -- snacks.nvim's own design, so it's simply omitted rather than listed
      -- with enabled = false. zen-mode.nvim (lua/plugins/zen.lua) already
      -- covers distraction-free writing, so snacks' own zen module is
      -- deliberately left off.
      picker = {
        enabled = true,
      },
    },
  },
}
