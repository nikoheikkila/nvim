-- snacks.nvim picker keymaps (plugins/picker.lua). Rather than drive the async
-- picker UI, this tests the config seam synchronously: swap require("snacks")
-- for a capturing fake, invoke the keymap callbacks straight off the lazy spec,
-- and assert the options they pass through. `hidden = true` is what makes
-- dotfiles/dot-dirs searchable; `ignored` is left at its default so .gitignore
-- stays honoured (and .git/ is always excluded by snacks itself).
describe("snacks picker keymaps", function()
  local spec = require("plugins.picker")[1]

  local function find_key(desc)
    for _, k in ipairs(spec.keys) do
      if k.desc == desc then
        return k
      end
    end
    error("no keymap with desc " .. desc)
  end

  local project = require("config.project")
  local real_snacks
  local real_root
  local captured

  before_each(function()
    captured = nil
    real_snacks = package.loaded["snacks"]
    package.loaded["snacks"] = {
      picker = {
        files = function(opts)
          captured = opts
        end,
        grep = function(opts)
          captured = opts
        end,
      },
    }
    -- Both keymaps take their cwd from config.project.root(). Faking it on the
    -- module table is what proves they forward it rather than computing a root of
    -- their own -- asserting the real value would tautologically re-derive the
    -- implementation. project_spec.lua owns what root() itself returns.
    real_root = project.root
    project.root = function()
      return "/fake/project/root"
    end
  end)

  after_each(function()
    package.loaded["snacks"] = real_snacks
    project.root = real_root
    vim.fn.executable = nil -- drop any override, restoring real dispatch
  end)

  it("<leader><leader> finds files with hidden = true, scoped to the project root", function()
    find_key("Find Files (Project)")[2]()

    assert.equal(true, captured.hidden)
    assert.equal("/fake/project/root", captured.cwd)
  end)

  it("<leader>. greps with hidden = true when rg is present", function()
    local orig = vim.fn.executable
    vim.fn.executable = function(name)
      return name == "rg" and 1 or orig(name)
    end

    find_key("Grep Project (Text Search)")[2]()

    assert.equal(true, captured.hidden)
    assert.equal("/fake/project/root", captured.cwd)
  end)
end)
