return {
  {
    "lettertwo/laserwave.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("laserwave").setup({ transparent = true })
    end,
  },
}
