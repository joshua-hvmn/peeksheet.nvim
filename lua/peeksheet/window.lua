local M = {}
local config = require 'peeksheet.config'

local function make_separator(width)
  return string.rep('─', width)
end

function M.setup_buffer_keymaps(buf, win, raw_lines, width)
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

  -- Edit peeksheet.md
  vim.keymap.set('n', '/', function()
    require('peeksheet.search').start(buf)
  end, { buffer = buf, silent = true, desc = 'Search Peeksheet' })
end

function M.open_edit_mode(buf, win)
  local path = config.options.peeksheet_path

  -- Unlock buffer
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_set_option_value('readonly', false, { buf = buf })

  -- Load raw peeksheet.md content
  local edit_lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or { '# My Peeksheet', '', 'Add your custom notes here.' }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, edit_lines)

  -- Update title to signal edit mode
  vim.api.nvim_win_set_config(win, {
    title = '✏️  Editing Peeksheet  ✏️',
    title_pos = 'center',
  })

  -- Write and return to view
  vim.keymap.set('n', 'w', function()
    local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.fn.writefile(new_lines, path)
    vim.notify('Peeksheet saved.', vim.log.levels.INFO)
    M.reload_view(buf, win)
  end, { buffer = buf, silent = true, nowait = true, desc = 'Save Peeksheet' })

  -- Cancel edit and return to view
  vim.keymap.set('n', '<Esc>', function()
    M.reload_view(buf, win)
  end, { buffer = buf, silent = true, nowait = true })
end

function M.reload_view(buf, win)
  local path = config.options.peeksheet_path
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * config.options.width_ratio)

  local lines = M.build_lines(path, width)

  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('readonly', true, { buf = buf })

  vim.api.nvim_win_set_config(win, {
    title = config.options.title,
    title_pos = 'center',
  })

  -- Restore normal keymaps
  M.setup_buffer_keymaps(buf, win, lines, width)
end

function M.build_lines(path, width)
  -- Header hint bar
  local lines = {
    '  q: close   /: search   e: edit peeksheet.md',
    make_separator(width),
    '',
  }

  -- Peeksheet.md content
  local md_lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or { '# Peeksheet not found', '', 'Expected at: ' .. path }
  vim.list_extend(lines, md_lines)

  -- Separator before keymaps
  if config.options.enable_keymap_section then
    table.insert(lines, '')
    table.insert(lines, make_separator(width))
    table.insert(lines, '')
    local keymap_lines = require('peeksheet.keymaps').generate_keymap_section()
    vim.list_extend(lines, keymap_lines)
  end

  return lines
end

-- ------
function M.open()
  -- Dynamic size
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * config.options.width_ratio)
  local height = math.floor(ui.height * config.options.height_ratio)
  local col = math.floor((ui.width - width) / 2)
  local row = math.floor((ui.height - height) / 2)

  local path = config.options.peeksheet_path
  local lines = M.build_lines(path, width)

  -- Create Buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

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
  M.setup_buffer_keymaps(buf, win, lines, width)

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
