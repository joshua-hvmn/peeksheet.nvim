local M = {}
local config = require 'peeksheet.config'

function M.setup_buffer_keymaps(buf, win)
  local function close_win()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  -- Close with q or esc
  vim.keymap.set('n', 'q', close_win, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set('n', '<Esc>', close_win, { buffer = buf, silent = true, nowait = true })

  -- Search Binding
  if config.options.enable_search then
    vim.keymap.set('n', '/', function()
      require('peeksheet.search').start(buf)
    end, { buffer = buf, silent = true, desc = 'Search Peeksheet' })
  end
end

function M.open()
  local path = config.options.peeksheet_path
  local lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or { '# Peeksheet not found', '', 'Expected at: ' .. path }

  -- Auto-insert keymap section if enabled
  if config.options.enable_keymap_section then
    local keymap_lines = require('peeksheet.keymaps').generate_keymap_section()
    table.insert(lines, '')
    vim.list_extend(lines, keymap_lines)
  end

  -- Create Buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Dynamic size
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * config.options.width_ratio)
  local height = math.floor(ui.height * config.options.height_ratio)
  local col = math.floor((ui.width - width) / 2)
  local row = math.floor((ui.height - height) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = config.options.border,
    title = config.options.title,
    title_pos = 'center',
  })

  -- Apply keymaps
  M.setup_buffer_keymaps(buf, win)

  -- Styling
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf })
  vim.wo[win].conceallevel = 2
  vim.wo[win].concealcursor = 'nc'
  pcall(vim.treesitter.start, buf, 'markdown')

  -- Lock the buffer
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('readonly', true, { buf = buf })

  -- wipe buffer
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })

  return buf, win
end

return M
