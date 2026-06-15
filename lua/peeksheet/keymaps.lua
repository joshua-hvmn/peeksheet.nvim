local M = {}

function M.generate_keymap_section()
	local lines = { "## Auto-Detected Keymaps", "" }

	-- get all normal keymaps that have descriptions
	for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
		if map.desc and map.desc ~= "" then
			table.insert(lines, string.format("- `%s` → %s", map.lhs, map.desc))
		end
	end

	-- TODO: LATER IMPROVEMENTS
	--  - support which-key groups
	--  - support buffer-local mappings
	--  - filter out noisy built-in mappings

	if #lines == 1 then
		table.insert(lines, "No keymaps with descriptions found.")
	end

	return lines
end

return M
