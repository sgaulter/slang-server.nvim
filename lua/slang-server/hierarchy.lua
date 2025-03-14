local NuiText = require("nui.text")
local NuiLine = require("nui.line")
local NuiSplit = require("nui.split")
local NuiTree = require("nui.tree")
local client = require("slang-server._lsp.client")
local highlights = require("slang-server._core.highlights")
local config = require("slang-server._core.config").CONFIG

---@class SlangServerSplits
---@field hierarchy? NuiSplit
local M = {}

---@class SlangNode : NuiTree.Node, slang_server.Item

---@param node SlangNode
---@param parent_node? SlangNode
local prepare_node = function(node, parent_node)
	local line = NuiLine()

	local decoration = config.kinds[client.kind_map[node.kind]]

	if node.kind == SlangKind.INSTANCE or node.kind == SlangKind.SCOPE then
		if node:has_children() and not node:is_expanded() then
			decoration = decoration.closed
		else
			decoration = decoration.open
		end
	end

	line:append(string.rep(" ", node:get_depth() - 1))
	line:append(decoration.icon .. " ", decoration.hl)
	line:append(node.instName .. " ", decoration.hl)

	return line
end

local parse_nodes
---@param nodes slang_server.Item[] | slang_server.Scope[]
---@return NuiTree.Node[]
parse_nodes = function(nodes)
	local nui_nodes = {}
	for _, node in pairs(nodes) do
		nui_nodes[#nui_nodes + 1] = NuiTree.Node(node, parse_nodes(node.children or {}))
	end

	return nui_nodes
end

---@param split NuiSplit
---@param tree NuiTree
local map_keys = function(split, tree)
	--TODO: configurable mappings

	-- Map to unmount (close) the hierarchy
	split:map("n", "q", function()
		split:unmount()
	end, { noremap = true })

	-- Space to toggle expand / collapse
	split:map("n", "<space>", function()
		local node = tree:get_node()

		if not node then
			return
		end

		local update = false
		update = node:is_expanded() and node:collapse() or node:expand()
		if update then
			tree:render()
		end
	end)
end

M.open = function()
	local split = NuiSplit({
		relative = "win",
		position = "left",
		size = 30,
		win_options = {
			number = false,
			relativenumber = false,
		},
	})

	split:mount()

	local header = NuiText("Slang-server", "@label")

	---@type slang_server.Item[] | slang_server.Scope[]
	local nodes = {
		{
			kind = SlangKind.INSTANCE,
			instName = "Mod",
			instLoc = { 1, 25 },
			children = {},
		},
		{
			kind = SlangKind.SCOPE,
			instName = "block_a",
			instLoc = { 2, 23 },
			children = {
				{
					kind = SlangKind.PARAM,
					instName = "param_1",
					instLoc = { 2, 25 },
				},
				{
					kind = SlangKind.PORT,
					instName = "port_1",
					instLoc = { 2, 40 },
				},
			},
		},
	}

	vim.api.nvim_set_hl_ns(highlights.ns_id)

	local tree = NuiTree({
		prepare_node = prepare_node,
		bufnr = split.bufnr,
		nodes = parse_nodes(nodes),
	})

	map_keys(split, tree)

	tree:render()

	local updated = false
	for _, node in pairs(tree.nodes.by_id) do
		updated = node:expand() or updated
	end
	if updated then
		tree:render()
	end
end

return M
