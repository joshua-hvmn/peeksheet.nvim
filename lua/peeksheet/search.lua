local M = {}

function M.start(buf)
  local win = vim.fn.bufwinid(buf)
  vim.ui.input({ prompt = 'Search Peeksheet: ' }, function(query)
    if not query or query == '' then
      return
    end
    if not vim.api.nvim_win_is_valid(win) then
      return
    end

    vim.api.nvim_win_call(win, function()
      local saved = vim.fn.getreg '/'
      -- Case-insensitive search and center the match
      local match = vim.fn.search('\\c' .. vim.fn.escape(query, [[\/]]))
      vim.fn.setreg('/', saved)
      if match > 0 then
        vim.cmd 'normal! zz'
      else
        vim.notify('No matches found for: ' .. query, vim.log.levels.WARN)
      end
    end)
  end)
end

return M
