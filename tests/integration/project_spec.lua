-- config/project.lua — where a project-scoped tool's search root comes from.
-- Covers detect()'s filesystem check and normalisation, root()'s precedence, and
-- the VimEnter chdir in config/autocmds.lua. See "Project Root Resolution" in
-- config.md for the rules these assert.
--
-- The harness runs `nvim -l` with no positional arguments, so argv(0) is "" and
-- startup_dir() memoises nil for the process. `:argadd` reaches the real capture
-- path anyway; the precedence tests override the accessor to get past the memo.
describe("config.project", function()
  local project = require("config.project")

  describe("detect", function()
    local dir, file, link

    setup(function()
      dir = vim.fn.tempname()
      assert.equal(1, vim.fn.mkdir(dir, "p"))
      file = vim.fs.joinpath(dir, "note.md")
      assert.equal(0, vim.fn.writefile({ "# note" }, file))
      link = vim.fn.tempname()
      assert.is_true(vim.uv.fs_symlink(dir, link))
    end)

    teardown(function()
      vim.fn.delete(link)
      vim.fn.delete(dir, "rf")
    end)

    it("returns the normalised absolute path of a directory", function()
      assert.equal(vim.fs.normalize(vim.fn.fnamemodify(dir, ":p")), project.detect(dir))
    end)

    it("normalises away a trailing slash", function()
      assert.equal(project.detect(dir), project.detect(dir .. "/"))
    end)

    it("resolves a relative argument against the current directory", function()
      assert.equal(vim.fs.normalize(vim.uv.cwd() .. "/lua"), project.detect("lua"))
    end)

    -- vim.fn.resolve is deliberately not called, so a symlinked directory keeps
    -- the name that was typed — `nvim <directory>` searches that directory, not
    -- whatever the link points at.
    it("keeps a symlinked directory unresolved", function()
      assert.equal(vim.fs.normalize(vim.fn.fnamemodify(link, ":p")), project.detect(link))
    end)

    it("returns nil for a file", function()
      assert.is_nil(project.detect(file))
    end)

    it("returns nil for a path that does not exist", function()
      assert.is_nil(project.detect(vim.fs.joinpath(dir, "missing")))
    end)

    it("returns nil for an empty string, as argv(0) gives with no argument", function()
      assert.is_nil(project.detect(""))
    end)

    it("returns nil for nil", function()
      assert.is_nil(project.detect(nil))
    end)
  end)

  describe("root", function()
    it("has no startup directory under this harness", function()
      -- `nvim -l` takes no positional arguments, so the first tier is empty and
      -- root() behaves exactly as the pre-existing git-root lookup did. The two
      -- unqualified assertions in picker_spec.lua depend on this.
      assert.is_nil(project.startup_dir())
      assert.equal(vim.fs.root(0, { ".git" }), project.root())
    end)

    it("prefers a startup directory over the enclosing git repository", function()
      local real_startup_dir = project.startup_dir
      finally(function()
        project.startup_dir = real_startup_dir
      end)
      project.startup_dir = function()
        return "/fake/vault"
      end

      assert.equal("/fake/vault", project.root())
    end)
  end)

  describe("startup directory", function()
    -- The one path that needs no fake: `:argadd` writes the arglist argv(0) reads,
    -- so this exercises the real capture -- only startup_dir()'s memo (already
    -- fixed at nil for this process) stands between it and a real `nvim <dir>`.
    it("is read from the first argument in the arglist", function()
      local dir = vim.fn.tempname()
      assert.equal(1, vim.fn.mkdir(dir, "p"))
      finally(function()
        vim.cmd("%argdelete")
        vim.fn.delete(dir, "rf")
      end)

      vim.cmd("argadd " .. vim.fn.fnameescape(dir))

      assert.equal(vim.fs.normalize(dir), project.detect(vim.fn.argv(0)))
    end)

    -- `once`, and VimEnter fires even under `nvim -l`, so the autocmd has already
    -- run and removed itself by the time specs load — an empty list is the
    -- evidence it fired. nvim_get_autocmds raises on an unknown group, so this
    -- also proves config/autocmds.lua registered the group at all.
    it("chdir autocmd has already run and removed itself", function()
      assert.same({}, vim.api.nvim_get_autocmds({ group = "startup_dir", event = "VimEnter" }))
    end)
  end)
end)
