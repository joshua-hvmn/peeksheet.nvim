local M = {}
local config = require 'peeksheet.config'

local header_buf, header_win = nil, nil
local keymap_section_start = nil

local VIEW_HEADER = '  q: close   /: search   e: edit or remap'
local EDIT_HEADER = '  w: write   C: cancel                   '

local function make_separator(width)
  return string.rep('─', width)
end

local function set_header_text(text)
  if header_buf and vim.api.nvim_buf_is_valid(header_buf) then
    vim.api.nvim_set_option_value('modifiable', true, { buf = header_buf })
    vim.api.nvim_buf_set_lines(header_buf, 0, -1, false, { text })
    vim.api.nvim_set_option_value('modifiable', false, { buf = header_buf })
  end
end

local function set_header_title(title)
  if header_win and vim.api.nvim_win_is_valid(header_win) then
    vim.api.nvim_win_set_config(header_win, {
      title = title,
      title_pos = 'center',
    })
  end
end

local function open_header(width, col, row)
  header_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(header_buf, 0, -1, false, { VIEW_HEADER })

  header_win = vim.api.nvim_open_win(header_buf, false, {
    relative = 'editor',
    width = width,
    height = 1,
    col = col,
    row = row,
    style = 'minimal',
    border = { '╭', '─', '╮', '│', '', '', '', '│' },
    title = config.options.title,
    title_pos = 'center',
    focusable = false,
    zindex = 60,
  })

  vim.api.nvim_set_option_value('winhl', 'Normal:NormalFloat', { win = header_win })
end

local function close_header()
  if header_win and vim.api.nvim_win_is_valid(header_win) then
    vim.api.nvim_win_close(header_win, true)
  end
  header_win, header_buf = nil, nil
end

function M.build_lines(path, width)
  local lines = {}

  -- Peeksheet.md content
  local md_lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or { '# Peeksheet not found', '', 'Expected at: ' .. path }
  vim.list_extend(lines, md_lines)

  -- Separator before keymaps
  if config.options.enable_keymap_section then
    table.insert(lines, '')
    table.insert(lines, make_separator(width))
    table.insert(lines, '')
    keymap_section_start = #lines + 1
    local keymap_lines = require('peeksheet.keymaps').generate_keymap_section()
    vim.list_extend(lines, keymap_lines)
  end

  return lines
end

local function apply_view_options(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].foldcolumn = '0'
  vim.wo[win].colorcolumn = ''
  vim.wo[win].list = false
  vim.wo[win].conceallevel = 2
  vim.wo[win].concealcursor = 'nc'
end

function M.reload_view(buf, win, width)
  local path = config.options.peeksheet_path
  local lines = M.build_lines(path, width)

  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })

  set_header_title(config.options.title)
  set_header_text(VIEW_HEADER)

  -- Restore normal keymaps
  M.setup_buffer_keymaps(buf, win, width)
end

function M.open_edit_mode(buf, win, width)
  local path = config.options.peeksheet_path

  -- Unlock buffer
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })

  -- Load raw peeksheet.md content
  local edit_lines = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or { '# My Peeksheet', '', 'Add your custom notes here.' }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, edit_lines)

  -- Update title to signal edit mode
  set_header_title '✏️  Editing Peeksheet  ✏️'
  set_header_text(EDIT_HEADER)

  -- Write and return to view
  vim.keymap.set('n', 'w', function()
    local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.fn.writefile(new_lines, path)
    vim.notify('Peeksheet saved.', vim.log.levels.INFO)
    M.reload_view(buf, win, width)
  end, { buffer = buf, silent = true, nowait = true, desc = 'Save Peeksheet' })

  -- Cancel edit and return to view
  vim.keymap.set('n', 'C', function()
    M.reload_view(buf, win, width)
  end, { buffer = buf, silent = true, nowait = true })
end

function M.setup_buffer_keymaps(buf, win, width)
  local function close_win()
    close_header()
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
  vim.keymap.set('n', 'e', function()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local cursor_line = cursor[1]

    if keymap_section_start and cursor_line >= keymap_section_start then
      require('peeksheet.goto').remap_at_cursor(buf, win, function()
        M.reload_view(buf, win, width)
      end)
    else
      M.open_edit_mode(buf, win, width)
    end
  end, { buffer = buf, silent = true, desc = 'Edit Peeksheet' })
end

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

  open_header(width, col, row - 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    border = { '', '', '', '│', '╯', '─', '╰', '│' },
  })

  -- Apply keymaps
  apply_view_options(win)
  M.setup_buffer_keymaps(buf, win, width)

  -- Styling
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf })
  pcall(vim.treesitter.start, buf, 'markdown')

  -- Lock the buffer
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })

  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = close_header,
  })

  return buf, win
end

return M
