# peeksheet.nvim
A simple lazy.nvim plugin that shows a personal cheatsheet, which automatically detects keymaps that have descriptions.

# Installation:
Minimal default config:
```
return {
  'joshua-hvmn/peeksheet.nvim',
  lazy = false,
  config = function()
    require('peeksheet').setup {}
  end,
}
```

Example config showing default settings and `<leader>h` keymap for the `:Peeksheet` command
```
return {
  'joshua-hvmn/peeksheet.nvim',
  lazy = false,
  config = function()
    require('peeksheet').setup({
      peeksheet_path = vim.fn.stdpath("config") .. "/peeksheet.md",
      width_ratio = 0.65,
      height_ratio = 0.75,
      title = "💡 Peeksheet 💡",
      border = "rounded",
      enable_search = true,
      enable_keymap_section = true,
      show_buffer_keymaps = true,
      ignored_keymaps = {
        "ZZ",
        "ZQ",
        "<Ignore>",
        "<Nop>",
        "<Left>",
        "<Right>",
        "<Up>",
        "<Down>",
      },
    })
  end,
  keys = {
    { '<leader>h', '<cmd>Peeksheet<CR>', desc = 'Open Peeksheet' },
  },
}
```
