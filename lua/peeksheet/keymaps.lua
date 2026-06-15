local M = {}
local config = require("peeksheet.config")

-- Helper function to display leader
local function format_lhs(lhs)
	local leader = vim.g.mapleader or " "

	-- convert space to <leader>
	if leader == " " or leader == "<Space>" then
		lhs = lhs:gsub("^ ", "<leader>")
		lhs = lhs:gsub("<Space>", "<leader>")
	end
	-- You can add more replacements here (e.g. <LocalLeader>)
	local local_leader = vim.g.maplocalleader
	if local_leader == " " then
		lhs = lhs:gsub("^ ", "<localleader>")
	end

	return lhs
end

-- Group keymaps by prefix
local function get_group_key(lhs)
	lhs = format_lhs(lhs)

	if lhs:find("^<leader>") then
		local prefix = lhs:match("^<leader>[^%s<]") or "<leader>"
		return prefix
	elseif lhs:find("^<localleader>") then
		return "<localleader>"
	elseif lhs:find("^<C%-") then
		return "Ctrl"
	elseif lhs:find("^<[^%s>]+>$") then
		return "Special"
	else
		return "Other"
	end
end

function M.generate_keymap_section()
	local lines = { "## Auto-Detected Keymaps", "" }
	local ignored = config.options.ignored_keymaps or {}
	local groups = {}

	local function add_mapping(lhs, desc, suffix)
		if vim.tbl_contains(ignored, lhs) then
			return
		end
		local nice_lhs = format_lhs(lhs)
		local group = get_group_key(lhs)
		local text = string.format("- `%s` → %s%s", nice_lhs, desc, suffix or "")

		groups[group] = groups[group] or {}
		table.insert(groups[group], text)
	end

	-- get all normal keymaps that have descriptions
	for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
		if map.desc and map.desc ~= "" then
			add_mapping(map.lhs, map.desc)
		end
	end

	-- TODO: LATER IMPROVEMENTS
	--  - support which-key groups
	--  - filter out noisy built-in mappings

	-- Show buffer-local keymaps
	if config.options.show_buffer_keymaps then
		for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
			if map.desc and map.desc ~= "" then
				add_mapping(map.lhs, map.desc, " **(buffer)**")
			end
		end
	end

	-- sort groups and build final output
	local group_order = { "<leader>", "<localleader>", "Ctrl", "Special", "Other" }
	local sorted_groups = {}

	for group, _ in pairs(groups) do
		table.insert(sorted_groups, group)
	end

	local function get_index(tbl, value)
		for index, val in ipairs(tbl) do
			if val == value then
				return index
			end
		end
		return 999
	end

	table.sort(sorted_groups, function(a, b)
		local idx_a = get_index(group_order, a)
		local idx_b = get_index(group_order, b)
		return idx_a < idx_b
	end)

	for _, group in ipairs(sorted_groups) do
		if #groups[group] > 0 then
			table.insert(lines, "### " .. group)
			-- sort mappings inside each group
			table.sort(groups[group])
			vim.list_extend(lines, groups[group])
			table.insert(lines, "")
		end
	end

	if #lines == 1 then
		table.insert(lines, "No keymaps with descriptions found.")
	end

	return lines
end

return M
