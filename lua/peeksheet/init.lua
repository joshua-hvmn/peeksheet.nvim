local M = {}

M.options = {}

function M.setup(opts)
  require('peeksheet.config').setup(opts)
end

function M.open()
  require('peeksheet.window').open()
end

return M
