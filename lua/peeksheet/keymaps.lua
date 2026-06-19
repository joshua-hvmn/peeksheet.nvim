local M = {}
local config = require 'peeksheet.config'

-- Helper function to display leader
local function format_lhs(lhs)
  local leader = vim.g.mapleader or ' '

  -- convert space to <leader>
  if leader == ' ' or leader == '<Space>' then
    lhs = lhs:gsub('^ ', '<leader>'):gsub('<Space>', '<leader>')
  end
  -- You can add more replacements here (e.g. <LocalLeader>)
  local local_leader = vim.g.maplocalleader
  if local_leader == ' ' then
    lhs = lhs:gsub('^ ', '<localleader>')
  end

  return lhs
end

-- Group keymaps by prefix
local function get_group_key(lhs)
  lhs = format_lhs(lhs)

  if lhs:find '^<leader>' then
    return '<leader>'
  elseif lhs:find '^<localleader>' then
    return '<localleader>'
  elseif lhs:find '^<C%-' then
    return 'Ctrl'
  elseif lhs:find '^<[^%s>]+>$' then
    return 'Special'
  else
    return 'Other'
  end
end

local function get_editable_lhs_set()
  local keymaps_file = config.options.keymaps_file
  local set = {}

  if not keymaps_file or vim.fn.filereadable(keymaps_file) == 0 then
    return set
  end

  local file_lines = vim.fn.readfile(keymaps_file)
  for _, line in ipairs(file_lines) do
    for token in line:gmatch '["\'](<[^"\']+>[^"\']*)["\']' do
      set[token] = true
    end
    for token in line:gmatch '["\']( [^"\']*)["\']' do
      set[token] = true
    end
  end

  return set
end

function M.generate_keymap_section()
  local lines = { '## Auto-Detected Keymaps', '' }
  local editable_set = get_editable_lhs_set()

  -- legend
  table.insert(lines, '✏️ = editable via `e` (defined in your keymaps file)')
  table.insert(lines, '')

  local ignored = config.options.ignored_keymaps or {}
  local groups = {}

  local function is_editable(lhs)
    local nice_lhs = format_lhs(lhs)
    return editable_set[lhs] or editable_set[nice_lhs]
  end

  local function add_mapping(lhs, desc, suffix)
    if vim.tbl_contains(ignored, lhs) then
      return
    end
    local nice_lhs = format_lhs(lhs)
    local group = get_group_key(lhs)
    local marker = is_editable(lhs) and '→ ✏️' or '→'
    local text = string.format('- `%s` %s %s%s', nice_lhs, marker, desc, suffix or '')

    groups[group] = groups[group] or {}
    table.insert(groups[group], text)
  end

  -- get all normal keymaps that have descriptions
  for _, map in ipairs(vim.api.nvim_get_keymap 'n') do
    if map.desc and map.desc ~= '' then
      add_mapping(map.lhs, map.desc)
    end
  end

  -- TODO: LATER IMPROVEMENTS
  --  - support which-key groups
  --  - filter out noisy built-in mappings

  -- Show buffer-local keymaps
  if config.options.show_buffer_keymaps then
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
      if map.desc and map.desc ~= '' then
        add_mapping(map.lhs, map.desc, ' **(buffer)**')
      end
    end
  end

  -- sort groups and build final output
  local group_order = { '<leader>', '<localleader>', 'Ctrl', 'Special', 'Other' }
  local sorted_groups = {}

  for group, _ in pairs(groups) do
    table.insert(sorted_groups, group)
  end

  local order_index = {}
  for i, g in ipairs(group_order) do
    order_index[g] = i
  end

  table.sort(sorted_groups, function(a, b)
    return (order_index[a] or 999) < (order_index[b] or 999)
  end)

  for _, group in ipairs(sorted_groups) do
    if #groups[group] > 0 then
      table.insert(lines, '### ' .. group)
      -- Alphabetical sort within groups
      table.sort(groups[group], function(a, b)
        local lhs_a = a:match '`([^`]+)`' or a
        local lhs_b = b:match '`([^`]+)`' or b
        local lower_a = lhs_a:lower()
        local lower_b = lhs_b:lower()
        if lower_a == lower_b then
          return lhs_a > lhs_b
        end
        return lower_a < lower_b
      end)
      vim.list_extend(lines, groups[group])
      table.insert(lines, '')
    end
  end

  if #lines <= 4 then
    table.insert(lines, 'No keymaps with descriptions found.')
  end

  return lines
end

return M
