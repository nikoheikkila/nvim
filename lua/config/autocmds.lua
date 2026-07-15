local path_utils = require("lib.path_utils")

-- Create the target file's parent directory on save if it doesn't exist yet,
-- so `:e /new/nested/path/file` followed by `:w` succeeds without a manual mkdir.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("auto_create_dir", { clear = true }),
  callback = function(event)
    if path_utils.has_uri_scheme(event.match) then
      return
    end
    local dir = vim.fn.fnamemodify(event.match, ":p:h")
    vim.fn.mkdir(dir, "p")
  end,
})

-- Auto-save: write the buffer on leaving insert mode, and ~1s (debounced)
-- after any text change. `:update` only writes when modified; auto_create_dir
-- above still fires, so saves into new directories work. Buffer guards live
-- in lib/save_utils so Busted can cover them.
local save_utils = require("lib.save_utils")

local DEBOUNCE_MS = 1000

-- bufnr -> generation of the most recent change. A deferred save fires only
-- if its generation is still current. Cancel by BUMPING the counter, never by
-- resetting to nil — a nil-reset lets a stale closure match a restarted count.
local pending = {}

local function save(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if
    not save_utils.should_autosave({
      name = vim.api.nvim_buf_get_name(buf),
      buftype = vim.bo[buf].buftype,
      modified = vim.bo[buf].modified,
      modifiable = vim.bo[buf].modifiable,
      readonly = vim.bo[buf].readonly,
    })
  then
    return
  end
  vim.api.nvim_buf_call(buf, function()
    -- `silent` (not `silent!`): hide the "written" message, keep real errors.
    local ok, err = pcall(vim.cmd, "silent update")
    if not ok then
      vim.notify("Auto-save failed: " .. err, vim.log.levels.WARN)
    end
  end)
end

local group = vim.api.nvim_create_augroup("auto_save", { clear = true })

vim.api.nvim_create_autocmd("InsertLeave", {
  group = group,
  callback = function(event)
    pending[event.buf] = (pending[event.buf] or 0) + 1
    save(event.buf)
  end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(event)
    local buf = event.buf
    pending[buf] = (pending[buf] or 0) + 1
    local gen = pending[buf]
    -- defer_fn is schedule-wrapped: safe to run ex commands from the timer.
    vim.defer_fn(function()
      if pending[buf] == gen then
        save(buf)
      end
    end, DEBOUNCE_MS)
  end,
})
