local NuiText = require("nui.text")
local NuiLine = require("nui.line")
local NuiSplit = require("nui.split")
local NuiTree = require("nui.tree")
local client = require("slang-server._lsp.client")
local highlights = require("slang-server._core.highlights")
local config = require("slang-server._core.config").CONFIG

local M = {}

---@class slang-server.hierarchy.state
---@field open boolean
---@field scope string?
---@field split NuiSplit?
---@field tree NuiTree?
---@field text_bufnr integer?

---@type slang-server.hierarchy.state
M.state = { open = false }

-- M.state.text_buffer returns the most recently focused text buffer
setmetatable(M.state, {
	__index = function(self, _k)
		if _k == "text_bufnr" then
			local cur_buffer = vim.api.nvim_get_current_buf()
			if self.split and self.split.bufnr == cur_buffer then
				return vim.fn.bufnr("#")
			else
				return cur_buffer
			end
		end
	end,
})

local on_close = function()
	if not M.state.open then
		return
	end
	M.state.tree = nil
	M.state.split = nil
	M.state.open = false
end

---@class slang-server.TreeNode
---@field id string
---@field kind slang-server.SlangKind
---@field instName string
---@field instLoc slang-server.SourceLoc
---@field type string?
---@field value string?
---@field children slang-server.TreeNode[]?
---@field declName string?
---@field declLoc slang-server.SourceLoc?

---@param node NuiTree.Node
---@param parent_node NuiTree.Node?
local prepare_node = function(node, parent_node)
	local line = NuiLine()

	if node.text then
		line:append(node.text, "Comment")
	else
		local decoration = config.kinds[string.lower(node.kind)]

		if node.kind == "Instance" or node.kind == "Scope" then
			if node:has_children() and not node:is_expanded() then
				decoration = decoration.closed
			else
				decoration = decoration.open
			end
		elseif node.kind == "Port" then
			if string.find(node.type, "^input") then
				decoration = decoration.input
			elseif string.find(node.type, "^output") then
				decoration = decoration.output
			else
				decoration = decoration.inout
			end
		end

    local box = ""
		if parent_node then
			box = node.id == parent_node.children[#parent_node.children].id and "┗" or "┣"
		end

		line:append(string.rep(" ", node:get_depth() - 1) .. box, highlights.HIER_SUBTLE)
		line:append(" " .. decoration.icon, decoration.hl)
		line:append(" " .. node.instName, decoration.hl)
		if node.type and node.type ~= "" then
			line:append(" " .. node.type, highlights.HIER_SUBTLE)
		else
			line:append(" " .. string.lower(node.kind), highlights.HIER_SUBTLE)
		end
	end

	return line
end

local parse_nodes
---@param nodes slang-server.TreeNode[]
---@param parent NuiTree.Node?
---@return NuiTree.Node[]
parse_nodes = function(nodes, parent)
	local nui_nodes = {}
	for _, node in pairs(nodes) do
		node.id = parent and parent.id .. "." .. node.instName or node.instName
		nui_nodes[#nui_nodes + 1] = NuiTree.Node(node, parse_nodes(node.children or {}))
	end

	return nui_nodes
end

---@param nodes slang-server.lsp.Item[] | slang-server.lsp.Scope[]
local show_nodes = function(nodes)
	if not M.state.open then
		return
	end
	local tree_nodes = parse_nodes(nodes)

	M.state.tree:set_nodes(tree_nodes)

	M.state.tree:render(2)
end

---@param split NuiSplit
---@param tree NuiTree
local map_keys = function(split, tree)
	--TODO: configurable mappings

	-- Map to unmount (close) the hierarchy
	split:map("n", "q", function()
		split:unmount()
	end, { noremap = true })

	-- <CR> to jump to the source location
	split:map("n", "<cr>", function()
		local node = tree:get_node()
		if not node then
			return
		end

		local buf = vim.uri_to_bufnr(node.instLoc.uri)
		local start = node.instLoc.range.start
		local win = vim.fn.win_findbuf(M.state.text_bufnr)[1]

		vim.api.nvim_win_set_buf(win, buf)
		vim.api.nvim_win_set_cursor(win, { start.line + 1, start.character })
		vim.api.nvim_set_current_win(win)
	end)

	-- Space to toggle expand / collapse
	split:map("n", "<space>", function()
		local node = tree:get_node()

		if not node then
			return
		end

		local update = false
		update = node:is_expanded() and node:collapse() or node:expand()
		if update then
			tree:render(2)
		end
	end)
end

---@param msg string
---@param opts {parent_id: string?, hl: string?}?
local message = function(msg, opts)
	local tree = M.state.tree
	opts = opts or {}

	if not tree then
		return
	end

	local text = NuiText(msg, opts.hl)

	tree:set_nodes({
		NuiTree.Node({
			text = text,
			id = (opts.parent_id or "") .. "__message",
		}),
	}, opts.parent_id)

	tree:render(2)
end

---@param msg string
local on_failure = function(msg)
	message(msg)
end

---@param top slang-server.HierarchyPath? The top level at which to initialise the hierarchy
M.show = function(top)
	if M.state.open then
		return
	else
		local hierarchy_config = config.hierarchy
		local split = NuiSplit({
			relative = "win",
			position = hierarchy_config.position,
			size = hierarchy_config.size,
			win_options = {
				number = false,
				relativenumber = false,
			},
		})

		local event = require("nui.utils.autocmd").event
		split:on(event.BufUnload, on_close, { once = true })

		split:mount()
		vim.api.nvim_set_hl_ns(highlights.ns_id)

		local header = NuiLine()
		header:append("Slang-server", highlights.HIER_HEADING)
		header:render(split.bufnr, highlights.ns_id, 1, 1)

		local tree = NuiTree({
			prepare_node = prepare_node,
			bufnr = split.bufnr,
		})

		map_keys(split, tree)

		M.state.open = true
		M.state.split = split
		M.state.tree = tree

		message("Loading scope...", { hl = highlights.HIER_SUBTLE })

		client.getScope(M.state.text_bufnr, {
			on_success = show_nodes,
			on_failure = function(msg)
				message(msg, { hl = highlights.HIER_ERROR })
			end,
		}, { hierPath = top or "" })
	end
end

---@param node NuiTree.Node?
M.expand_all = function(node)
	if not M.state.open then
		return
	end

	node = node or M.state.tree:get_node()
	if not node then
		return
	end

	local updated = false
	if node:has_children() then
		updated = node:expand() or updated

		for _, child in ipairs(node.children) do
			M.expand(child)
		end
	end
	if updated then
		M.state.tree:render(2)
	end
end

-- M.toggle = function()
-- 	if M.state.open then
-- 		M.on_close()
-- 	else
-- 		M.show()
-- 	end
-- end
return M
