-- Project-wide search & replace: grug-far.nvim driven as a centred modal float.
--
-- grug-far has no float mode of its own, but its `windowCreationCommand` is a
-- string handed to vim.cmd() *after* it has recorded the current window as
-- `prevWin` (grug-far.lua, `_createWindow`). Pointing that command at
-- open_float() below therefore yields a float while goto/open actions still
-- target the editor window underneath it.
--
-- One named instance backs <leader>S, and nothing short of grug-far's own close
-- (\c) or quitting Neovim destroys it: q/<Esc> and jumping to a result (<CR>)
-- only hide the float. The buffer stays loaded, unlisted, with its inputs and
-- results, and the next <leader>S re-shows it — so an accidental close loses no
-- typing. Plain :GrugFar is left on grug-far's defaults (a vertical split):
-- every override here is passed to this instance's open() call, not to setup().
local paths = require("config.paths")
local project = require("config.project")
local search_replace_utils = require("lib.search_replace_utils")
local yaml_utils = require("lib.yaml_utils")

local M = {}

M.INSTANCE = "search_replace"

-- grug-far's keymaps for this instance. The help line atop the modal and the
-- g? window label each action with the Normal-mode lhs given here, in
-- grug-far's fixed order, and leave out every action whose lhs is false — so
-- this table is both the keys and what the modal advertises. A string lhs binds
-- Normal and Insert mode, which is where typing happens.
--
-- Where setup_buffer maps the same lhs (<C-s>, <C-y>, <CR>, q), its map
-- replaces grug-far's: the label stays, the behaviour is ours. That is how Close
-- reads "q" while q only hides.
--
-- Unbound on purpose: the Sync family (Replace and Apply Next cover applying),
-- Open/Open Next/Open Prev (they load files into the window hidden behind the
-- float; unbinding also gives <Up>/<Down> back to cursor movement), Refresh
-- (re-showing and typing both search), and the rarer Quickfix, Abort, History
-- Add (history saves itself), Apply Prev, Toggle Show Search Command and Swap
-- Replacement Interpreter.
local KEYMAPS = {
  help = { n = "g?" },
  replace = "<C-s>",
  historyOpen = "<C-t>",
  gotoLocation = { n = "<CR>" },
  applyNext = "<C-y>",
  close = { n = "q" },
  swapEngine = "<C-e>",
  previewLocation = "<C-p>",
  nextInput = "<Tab>",
  prevInput = "<S-Tab>",
  syncLocations = false,
  syncLine = false,
  syncNext = false,
  syncPrev = false,
  syncFile = false,
  openLocation = false,
  openNextLocation = false,
  openPrevLocation = false,
  refresh = false,
  qflist = false,
  abort = false,
  historyAdd = false,
  applyPrev = false,
  toggleShowCommand = false,
  swapReplacementInterpreter = false,
}

-- Float size ratios from config.yml (`config.searchReplace.*`), read once per
-- session like config/vale.lua's init_options.
local settings

function M.settings()
  if not settings then
    settings = search_replace_utils.resolve_config(yaml_utils.read_file(paths.config_file("config.yml")))
  end
  return settings
end

-- grug-far's windowCreationCommand target: open and focus a centred float on a
-- throwaway buffer, which grug-far immediately swaps for its own (the
-- bufhidden=wipe scratch buffer then disappears).
--
-- style = "minimal" is load-bearing: a float otherwise inherits the window
-- options of the window it was opened from, and config/folding.lua sets
-- `statuscolumn` per window in markdown and LSP buffers. grug-far sets the
-- options it needs (foldcolumn, wrap, ...) on the window afterwards.
function M.open_float()
  local geometry = search_replace_utils.float_geometry(vim.o.columns, vim.o.lines - vim.o.cmdheight, M.settings())
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"

  return vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = geometry.row,
    col = geometry.col,
    width = geometry.width,
    height = geometry.height,
    style = "minimal",
    border = "rounded",
    title = " Search & Replace ",
    title_pos = "center",
  })
end

-- Search scope, matching <leader>.: the project root when it differs from the
-- cwd grug-far would otherwise search. Spaces are backslash-escaped because the
-- Paths input splits on unescaped whitespace.
local function scope_prefill()
  local root = vim.fs.normalize(project.root())
  if root == vim.fs.normalize(vim.uv.cwd()) then
    return nil
  end
  return (root:gsub(" ", "\\ "))
end

-- The visual selection as a search prefill, or nil outside Visual mode. Read
-- before the float opens: entering it ends Visual mode. Taken here rather than
-- left to grug-far (visualSelectionUsage) so a re-shown instance gets it too.
local function visual_selection()
  if not vim.fn.mode():match("^[vV\22]") then
    return nil
  end
  return require("grug-far").get_current_visual_selection(true)
end

-- Hide the float after a jump, so the code it opened is not left underneath it.
-- gotoLocation is a no-op when the cursor is not on a result line, in which
-- case focus stays in the float and so does the float.
local function goto_and_hide(instance)
  local float = vim.api.nvim_get_current_win()
  instance:goto_location()
  if vim.api.nvim_get_current_win() ~= float then
    instance:hide()
  end
end

-- Whether the cursor is on a match in the results list. Reaches into grug-far's
-- internals (render.resultsList and the instance's `_context`, the same pair its
-- own gotoLocation action uses) because the public instance API has no such
-- query. search_replace_spec presses <C-y> from an input line, so a grug-far
-- change that breaks this fails a test rather than going quiet.
local function on_match(instance)
  local results = require("grug-far.render.resultsList")
  local location = results.getResultLocationAtCursor(instance:get_buf(), instance._context)
  return location ~= nil and location.lnum ~= nil
end

-- <C-y>: apply the change under the cursor and move to the next one. grug-far's
-- applyChange silently does nothing off a match, so from an input (where the
-- cursor is while typing) start at the first match instead. open_location is
-- off: it would load the file into the editor window hidden behind the float.
local function apply_one(instance)
  vim.cmd.stopinsert()
  if not on_match(instance) and not instance:goto_next_match() then
    return -- no matches at all
  end
  instance:apply_next_change({ open_location = false })
end

-- <C-s>: apply every replacement (grug-far's Replace).
local function apply_all(instance)
  vim.cmd.stopinsert()
  instance:replace()
end

-- Buffer-local keys layered over grug-far's own (which setupBuffer has already
-- set by the time open() returns, so these win). Also unlists the buffer: it is
-- not transient, because hiding needs it to survive having no window, but it
-- should still stay out of the bufferline.
local function setup_buffer(instance)
  local buf = instance:get_buf()
  vim.bo[buf].buflisted = false

  local function map(modes, lhs, action, desc)
    vim.keymap.set(modes, lhs, function()
      action(instance)
    end, { buffer = buf, nowait = true, desc = "Search & Replace: " .. desc })
  end
  map("n", "q", instance.hide, "close (keeps input)")
  map("n", "<Esc>", instance.hide, "close (keeps input)")
  map("n", "<CR>", goto_and_hide, "go to location")
  map({ "n", "i" }, "<C-s>", apply_all, "apply all")
  map({ "n", "i" }, "<C-y>", apply_one, "apply this one")
  -- Destroying the instance, for a fresh start. Unlisted in the help line:
  -- grug-far's Close slot is labelled with q, which only hides.
  map("n", "<localleader>c", instance.close, "start over")
end

-- Re-show the hidden instance. Results are searched afresh unless the inputs
-- are about to change anyway (which triggers grug-far's own search): files may
-- have changed while it was hidden, and <C-y> writes a result line back to its
-- file as shown, so a stale line would overwrite those edits.
local function reopen(instance, selection)
  instance:open()
  if selection then
    instance:update_input_values({ search = selection }, false)
  elseif instance:get_status_info().status ~= "progress" then
    instance:search()
  end
  return instance
end

-- <leader>S. Re-shows the hidden instance when there is one (a visual selection
-- replaces its search), otherwise opens a fresh one in the float. <Tab>/<S-Tab>
-- move between inputs in Insert mode too (grug-far binds them in Normal only):
-- typing happens in Insert mode, and a literal tab is `\t` in the regex anyway.
function M.open()
  if vim.fn.executable("rg") == 0 then
    vim.notify("Search & Replace needs ripgrep (rg) on PATH", vim.log.levels.ERROR)
    return
  end

  local grug_far = require("grug-far")
  local selection = visual_selection()

  if grug_far.has_instance(M.INSTANCE) then
    return reopen(grug_far.get_instance(M.INSTANCE), selection)
  end

  local instance = grug_far.open({
    instanceName = M.INSTANCE,
    windowCreationCommand = "lua require('config.search_replace').open_float()",
    openTargetWindow = { preferredLocation = "prev" },
    visualSelectionUsage = "ignore",
    keymaps = KEYMAPS,
    prefills = { search = selection, paths = scope_prefill() },
  })
  setup_buffer(instance)
  return instance
end

return M
