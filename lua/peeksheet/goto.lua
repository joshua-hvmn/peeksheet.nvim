local M = {}
local config = require 'peeksheet.config'

-- parse lhs out of peeksheet keymap line
local function parse_lhs(line)
  return line:match '^%- `([^`]+)`'
end

local function normalize_ctrl_case(s)
  return s:gsub('<C%-(%a)>', function(letter)
    return '<C-' .. letter:upper() .. '>'
  end)
end

-- find existing keymap entry to preserve rhs/opts
local function find_keymap(lhs)
  local leader = vim.g.mapleader or ' '
  local raw_lhs = lhs:gsub('<leader>', leader)

  local function normalize(s)
    return normalize_ctrl_case(s):lower():gsub('%s+', '')
  end
  local norm = normalize(raw_lhs)

  for _, map in ipairs(vim.api.nvim_get_keymap 'n') do
    if normalize(map.lhs) == norm then
      return map
    end
  end

  for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
    if normalize(map.lhs) == norm then
      return map
    end
  end

  return nil
end

-- search for keymaps
local function find_lhs_in_file(filepath, lhs)
  if vim.fn.filereadable(filepath) == 0 then
    return nil
  end

  local norm_target = normalize_ctrl_case(lhs):lower()

  local file_lines = vim.fn.readfile(filepath)
  for i, line in ipairs(file_lines) do
    local norm_line = normalize_ctrl_case(line):lower()
    if norm_line:find(norm_target, 1, true) then
      return i, line
    end
  end

  return nil
end

-- rewrite lhs in file
local function rewrite_lhs_in_file(filepath, lnum, old_lhs, new_lhs)
  local file_lines = vim.fn.readfile(filepath)
  if not file_lines or #file_lines < lnum then
    return false, 'Could not read file or line number out of range'
  end

  local target = file_lines[lnum]
  local norm_target_line = normalize_ctrl_case(target):lower()
  local norm_old = normalize_ctrl_case(old_lhs):lower()

  local start_idx = norm_target_line:find(norm_old, 1, true)
  if not start_idx then
    return false, 'Could not find lhs in source line: ' .. target
  end

  local actual_old_len = #old_lhs
  local prefix = target:sub(1, start_idx - 1)
  local suffix = target:sub(start_idx + actual_old_len)

  file_lines[lnum] = prefix .. new_lhs .. suffix

  local result = vim.fn.writefile(file_lines, filepath)
  if result ~= 0 then
    return false, 'Failed to write file'
  end

  return true, nil
end

local function apply_live_remap(map, old_lhs, new_lhs)
  pcall(vim.keymap.del, 'n', old_lhs)

  local opts = {
    desc = map.desc,
    silent = map.silent == 1,
    noremap = map.noremap == 1,
    expr = map.expr == 1,
  }

  if map.callback then
    vim.keymap.set('n', new_lhs, map.callback, opts)
  elseif map.rhs then
    vim.keymap.set('n', new_lhs, map.rhs, opts)
  else
    return false
  end

  return true
end

function M.remap_at_cursor(buf, win, reload_fn)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local line = vim.api.nvim_buf_get_lines(buf, cursor[1] - 1, cursor[1], false)[1]

  if not line then
    return
  end

  local lhs = parse_lhs(line)
  if not lhs then
    vim.notify('No keymap found on this line.', vim.log.levels.WARN)
    return
  end

  local map = find_keymap(lhs)
  if not map then
    vim.notify('Could not find live mapping for: ' .. lhs, vim.log.levels.WARN)
    return
  end

  local keymaps_file = config.options.keymaps_file
  local lnum, source_line = find_lhs_in_file(keymaps_file, lhs)

  if not lnum then
    vim.notify('Could not find "' .. lhs .. '" in ' .. keymaps_file .. '. It may be defined elsewhere (like a plugin file).', vim.log.levels.WARN)
    return
  end

  vim.ui.input({
    prompt = 'Remap ' .. lhs .. ' to: ',
    default = lhs,
  }, function(new_lhs)
    if not new_lhs or new_lhs == '' or new_lhs == lhs then
      return
    end

    -- rewrite source file
    local ok, err = rewrite_lhs_in_file(keymaps_file, lnum, lhs, new_lhs)
    if not ok then
      vim.notify('Failed to update source file: ' .. (err or 'unknown error'), vim.log.levels.ERROR)
      return
    end

    -- apply live so the session matches
    local raw_lhs = lhs:gsub('<leader>', vim.g.mapleader or ' ')
    local raw_new_lhs = new_lhs:gsub('<leader>', vim.g.mapleader or ' ')
    local remapped = apply_live_remap(map, raw_lhs, raw_new_lhs)
    if not remapped then
      vim.notify('File updated but could not apply live remap.', vim.log.levels.WARN)
      return
    end

    vim.notify(string.format('Remapped %s → %s (live + saved to %s:%d)', lhs, new_lhs, keymaps_file, lnum), vim.log.levels.INFO)

    -- reload peeksheet
    reload_fn()
  end)
end

return M
