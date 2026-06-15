local M = {}

function M.start(buf)
	vim.ui.input({ prompt = "Search Peeksheet: " }, function(query)
		if not query or query == "" then
			return
		end

		vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
		vim.api.nvim_set_option_value("readonly", false, { buf = buf })

		vim.api.nvim_buf_call(buf, function()
			-- Case-insensitive search and center the match
			local match = vim.fn.search("\\c" .. vim.fn.escape(query, [[\/]]))
			if match then
				vim.cmd("normal! zz")
			else
				vim.notify("No matches found for: " .. query, vim.log.levels.WARN)
			end
		end)

		vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
		vim.api.nvim_set_option_value("readonly", true, { buf = buf })
	end)
end

return M
