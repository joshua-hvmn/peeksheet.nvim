if vim.g.loaded_peeksheet then
  return
end
vim.g.loaded_peeksheet = true

vim.api.nvim_create_user_command('Peeksheet', function()
  require('peeksheet').open()
end, { desc = 'Open Peeksheet hints menu' })
