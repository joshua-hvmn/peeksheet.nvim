local M = {}

-- parse lhs out of peeksheet keymap line
local function parse_lhs(line)
  return line:match '^%- `([^`]+)`'
end

-- verbose map to find source file and line number
local function get_map_source(lhs)
  local ok, output = pcall(vim.fn.execute, 'verbose nmap ' .. lhs)
  if not ok or not output then
    return nil, nil
  end

  local filepath = output:match 'Last set from ([^\n]+) line %d+'
  local lnum = output:match 'Last set from [^\n]+ line (%d+)'

  if filepath and lnum then
    filepath = vim.fn.expand(filepath)
    return filepath, tonumber(lnum)
  end

  return nil, nil
end

-- find existing keymap entry to preserve rhs/opts
local function find_keymap(lhs)
  local function normalize(s)
    return s:lower():gsub('%s+', '')
  end

  local norm = normalize(lhs)

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

-- rewrite lhs in file
local function rewrite_lhs_in_file(filepath, lnum, old_lhs, new_lhs)
  local file_lines = vim.fn.readfile(filepath)
  if not file_lines or #file_lines < lnum then
    return false, 'Could not read file or line number out of range'
  end

  local target = file_lines[lnum]
  local escaped_old = vim.pesc(old_lhs)

  if not target:find(escaped_old) then
    return false, 'Could not find lhs in source file: ' .. target
  end

  file_lines[lnum] = target:gsub(escaped_old, vim.pesc(new_lhs), 1)

  local result = vim.fn.writefile(file_lines, filepath)
  if result ~= 0 then
    return false, 'Failed to write file'
  end

  return nil, nil
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
    vim.notify('No keymap found on this line.', vim.log.leves.WARN)
    return
  end

  local map = find_keymap(lhs)
  if not map then
    vim.notify('Could not find live mapping for: ' .. lhs, vim.log.levels.WARN)
    return
  end

  local filepath, lnum = get_map_source(lhs)
  local config_dir = vim.fn.stdpath 'config'
  local in_config = filepath and filepath:find(config_dir, 1, true)

  if not in_config then
    vim.notify('Keymap is defined in a plugin, not your config. Cannot edit permanently.', vim.log.levels.WARN)
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
    local ok, err = rewrite_lhs_in_file(filepath, lnum, lhs, new_lhs)
    if not ok then
      vim.notify('Failed to update source file: ' .. (err or 'unknown error'), vim.log.levels.ERROR)
      return
    end

    -- apply live so the session matches
    local remapped = apply_live_remap(map, lhs, new_lhs)
    if not remapped then
      vim.notify('File updated but could not apply live remap.', vim.log.levels.WARN)
      return
    end

    vim.notify(string.format('Remapped %s → %s (live + saved to %s:%d)', lhs, new_lhs, filepath, lnum), vim.log.levels.INFO)

    -- reload peeksheet
    reload_fn()
  end)
end

return M
