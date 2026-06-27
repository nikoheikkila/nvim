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
