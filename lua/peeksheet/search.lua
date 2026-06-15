local M = {}

function M.start(buf)
	vim.ui.input({ prompt = "Search Peeksheet: " }, function(query)
		if not query or query == "" then
			return
		end

		vim.api.nvim_buf_call(buf, function()
			-- Case-insensitive search and center the match
			local ok = pcall(vim.fn.search, "\\c" .. vim.fn.escape(query, [[\/]]))
			if ok then
				vim.cmd("normal! zz")
			else
				vim.notify("No matches found for: " .. query, vim.log.levels.WARN)
			end
		end)
	end)
end

return M
