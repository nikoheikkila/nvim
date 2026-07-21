-- Run with: busted
-- Requires: brew install luarocks && luarocks install busted

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local M = require("lib.markdown_utils")

describe("find_image_path_at", function()
  it("simple image col inside", function()
    assert.are.equal(M.find_image_path_at("![alt](image.png)", 5), "image.png")
  end)

  it("simple image col at start", function()
    assert.are.equal(M.find_image_path_at("![alt](image.png)", 1), "image.png")
  end)

  it("simple image col at end", function()
    local line = "![alt](image.png)"
    assert.are.equal(M.find_image_path_at(line, #line), "image.png")
  end)

  it("col before image returns nil", function()
    assert.is_nil(M.find_image_path_at("text ![alt](image.png)", 1))
  end)

  it("col after image returns nil", function()
    local line = "![alt](image.png) trailing"
    assert.is_nil(M.find_image_path_at(line, #line))
  end)

  it("strips title attribute", function()
    assert.are.equal(M.find_image_path_at('![alt](image.png "My Title")', 5), "image.png")
  end)

  it("strips single quoted title", function()
    assert.are.equal(M.find_image_path_at("![alt](image.png 'title')", 5), "image.png")
  end)

  it("empty alt text", function()
    assert.are.equal(M.find_image_path_at("![](image.png)", 3), "image.png")
  end)

  it("path with directory", function()
    assert.are.equal(M.find_image_path_at("![alt](assets/img/photo.jpg)", 5), "assets/img/photo.jpg")
  end)

  it("remote url returned as is", function()
    assert.are.equal(M.find_image_path_at("![alt](https://example.com/img.png)", 5), "https://example.com/img.png")
  end)

  it("second of two images", function()
    local line = "![a](one.png) and ![b](two.png)"
    assert.are.equal(M.find_image_path_at(line, 20), "two.png")
  end)

  it("first of two images", function()
    local line = "![a](one.png) and ![b](two.png)"
    assert.are.equal(M.find_image_path_at(line, 3), "one.png")
  end)

  it("no image returns nil", function()
    assert.is_nil(M.find_image_path_at("just plain text", 5))
  end)

  it("empty line returns nil", function()
    assert.is_nil(M.find_image_path_at("", 1))
  end)
end)

describe("find_link_at", function()
  it("inline link col inside", function()
    assert.are.equal(M.find_link_at("[text](target.md)", 3), "target.md")
  end)

  it("inline link col at start", function()
    assert.are.equal(M.find_link_at("[text](target.md)", 1), "target.md")
  end)

  it("inline link col at end", function()
    local line = "[text](target.md)"
    assert.are.equal(M.find_link_at(line, #line), "target.md")
  end)

  it("image span col inside", function()
    assert.are.equal(M.find_link_at("![alt](image.png)", 5), "image.png")
  end)

  it("image span cursor on bang", function()
    assert.are.equal(M.find_link_at("![alt](image.png)", 1), "image.png")
  end)

  it("strips title attribute", function()
    assert.are.equal(M.find_link_at('[text](target.md "Title")', 3), "target.md")
  end)

  it("path with directory", function()
    assert.are.equal(M.find_link_at("[text](docs/notes/a.md)", 3), "docs/notes/a.md")
  end)

  it("remote url returned as is", function()
    assert.are.equal(M.find_link_at("[text](https://example.com)", 3), "https://example.com")
  end)

  it("col before link returns nil", function()
    assert.is_nil(M.find_link_at("text [a](b.md)", 1))
  end)

  it("col after link returns nil", function()
    local line = "[a](b.md) trailing"
    assert.is_nil(M.find_link_at(line, #line))
  end)

  it("second of two links", function()
    local line = "[a](one.md) and [b](two.md)"
    assert.are.equal(M.find_link_at(line, 20), "two.md")
  end)

  it("first of two links", function()
    local line = "[a](one.md) and [b](two.md)"
    assert.are.equal(M.find_link_at(line, 2), "one.md")
  end)

  it("no link returns nil", function()
    assert.is_nil(M.find_link_at("just plain text", 5))
  end)

  it("empty line returns nil", function()
    assert.is_nil(M.find_link_at("", 1))
  end)
end)

describe("is_remote_url", function()
  it("https is remote", function()
    assert.is_true(M.is_remote_url("https://example.com/image.png"))
  end)

  it("http is remote", function()
    assert.is_true(M.is_remote_url("http://example.com/image.png"))
  end)

  it("relative path is not remote", function()
    assert.is_false(M.is_remote_url("image.png"))
  end)

  it("absolute path is not remote", function()
    assert.is_false(M.is_remote_url("/home/user/image.png"))
  end)

  it("subdirectory path is not remote", function()
    assert.is_false(M.is_remote_url("assets/img/photo.jpg"))
  end)
end)

describe("replace_filename", function()
  it("replaces in subdirectory", function()
    assert.are.equal(M.replace_filename("images/foo.png", "bar.png"), "images/bar.png")
  end)

  it("replaces bare filename", function()
    assert.are.equal(M.replace_filename("foo.png", "bar.png"), "bar.png")
  end)

  it("deep path", function()
    assert.are.equal(M.replace_filename("a/b/c/foo.png", "new.jpg"), "a/b/c/new.jpg")
  end)

  it("changes extension", function()
    assert.are.equal(M.replace_filename("assets/photo.jpg", "photo.webp"), "assets/photo.webp")
  end)
end)

describe("toggle_checklist_line", function()
  it("empty line unchanged", function()
    assert.are.equal(M.toggle_checklist_line(""), "")
  end)

  it("unchecked to checked", function()
    assert.are.equal(M.toggle_checklist_line("- [ ] item"), "- [x] item")
  end)

  it("checked to unchecked", function()
    assert.are.equal(M.toggle_checklist_line("- [x] item"), "- [ ] item")
  end)

  it("uppercase X to unchecked", function()
    assert.are.equal(M.toggle_checklist_line("- [X] item"), "- [ ] item")
  end)

  it("bare list item dash", function()
    assert.are.equal(M.toggle_checklist_line("- item"), "- [ ] item")
  end)

  it("bare list item plus", function()
    assert.are.equal(M.toggle_checklist_line("+ item"), "+ [ ] item")
  end)

  it("bare list item star", function()
    assert.are.equal(M.toggle_checklist_line("* item"), "* [ ] item")
  end)

  it("plain line gets prefix", function()
    assert.are.equal(M.toggle_checklist_line("plain text"), "- [ ] plain text")
  end)

  it("indented checklist toggles", function()
    assert.are.equal(M.toggle_checklist_line("  - [ ] indented"), "  - [x] indented")
  end)

  it("indented plain line preserves indent", function()
    assert.are.equal(M.toggle_checklist_line("  plain"), "  - [ ] plain")
  end)

  it("indented bare list adds checkbox", function()
    assert.are.equal(M.toggle_checklist_line("  - item"), "  - [ ] item")
  end)

  it("double toggle roundtrip", function()
    local line = "- [ ] task"
    local checked = M.toggle_checklist_line(line)
    assert.are.equal(M.toggle_checklist_line(checked), line)
  end)
end)
