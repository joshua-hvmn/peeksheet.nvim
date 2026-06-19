# peeksheet.nvim
A simple lazy.nvim plugin that shows a personal, editable cheatsheet, and auto-detected, editable keymaps in a floating buffer.

# Installation:
Minimal default config:
```
return {
  'joshua-hvmn/peeksheet.nvim',
  lazy = true,
  cmd = 'Peeksheet',
  config = function()
    require('peeksheet').setup {}
  end,
}
```

Example config showing default settings and `<leader>h` keymap for the `:Peeksheet` command
```
return {
  'joshua-hvmn/peeksheet.nvim',
  lazy = true,
  cmd = 'Peeksheet',
  config = function()
    require('peeksheet').setup {
      peeksheet_path = vim.fn.stdpath 'config' .. '/peeksheet.md',
      keymaps_file = vim.fn.stdpath 'config' .. '/lua/core/keymaps.lua',
      width_ratio = 0.65,
      height_ratio = 0.75,
      title = '💡 Peeksheet 💡',
      border = 'rounded',
      enable_search = true,
      enable_keymap_section = true,
      show_buffer_keymaps = true,
      ignored_keymaps = {
        'ZZ',
        'ZQ',
        '<Ignore>',
        '<Nop>',
        '<Left>',
        '<Right>',
        '<Up>',
        '<Down>',
      },
    }
  end,
  keys = {
    { '<leader>h', '<cmd>Peeksheet<CR>', desc = 'Open Peeksheet' },
  },
}
```
