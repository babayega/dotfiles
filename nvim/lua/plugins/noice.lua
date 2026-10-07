return {
  {
    "folke/noice.nvim",
    opts = {
      cmdline = {
        format = {
          -- Work around a Treesitter query/parser mismatch triggered by Noice's
          -- popup cmdline highlighting for `:` commands on Neovim 0.12.
          cmdline = { lang = false },
        },
      },
    },
  },
}
