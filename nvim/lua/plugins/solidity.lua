-- Solidity support.
--
-- NOTE: LazyVim ships a `lang.solidity` extra, but it wires nvim-lspconfig's
-- `solidity_ls`, which points at `vscode-solidity-server` (an npm package).
-- This setup already runs `nomicfoundation-solidity-language-server` via
-- mason, which is the server the Foundry ecosystem ships and which works
-- here. Enabling the extra as-is would swap in a different server, so this
-- file configures the existing one directly and adds the one thing that was
-- missing: a formatter.
return {
  -- Enable the LSP. LazyVim does not auto-enable servers that are merely
  -- installed by mason, so without this it relies on mason + filetypes
  -- matching rather than on an explicit lspconfig entry.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        solidity_ls_nomicfoundation = {},
      },
    },
  },

  -- Keep mason installing the server. LazyVim configures mason with
  -- `ensure_installed`, so extend the list rather than replacing it.
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "nomicfoundation-solidity-language-server" })
    end,
  },

  -- Solidity treesitter parser.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "solidity" })
      end
    end,
  },

  -- The missing piece: conform had no formatter for `solidity` at all, so
  -- there was nothing to format a .sol file with. forge is already on PATH
  -- via ~/.zshenv (~/.foundry/bin).
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        solidity = { "forge_fmt" },
      },
    },
  },
}
