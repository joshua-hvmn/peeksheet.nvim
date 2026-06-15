local M = {}

M.defaults = {
	peeksheet_path = vim.fn.stdpath("config") .. "/peeksheet/peeksheet.md",
	width_ratio = 0.65,
	height_ratio = 0.75,
	title = "💡 Peeksheet 💡",
	border = "rounded",
	enable_search = true,
	enable_keymap_section = true,
	show_buffer_keymaps = true,
	ignored_keymaps = {
		"ZZ",
		"ZQ",
		"<Ignore>",
		"<Nop>",
		"<Left>",
		"<Right>",
		"<Up>",
		"<Down>",
	},
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
