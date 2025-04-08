local config = require("slang-server._core.config").CONFIG
local hl = require("slang-server._core.highlights")
local ui = require("slang-server._core.ui")
local client = require("slang-server._lsp.client")
local handlers = require("slang-server.handlers")
local util = require("slang-server.util")

local M = {}

---@type slang-server.hierarchy.State
M.state = { open = false }

-- M.state.text_bufnr returns the most recently focused text buffer
-- M.state.text_winnr returns the most recently focused text window
setmetatable(M.state, {
   ---@param _k string
   ---@return integer
   __index = function(self, _k)
      local cbuf = vim.fn.bufnr()
      local in_split = self.split and self.split.bufnr == cbuf

      local cwin = vim.fn.winnr()
      if _k == "text_bufnr" then
         return in_split and vim.fn.bufnr("#") or cbuf
      elseif _k == "text_winnr" then
         return in_split and vim.fn.winnr("#") or cwin
      end
   end,
})

---@param split NuiSplit
---@param tree NuiTree
local function map_keys(split, tree)
   ---@type table<string, slang-server.ui.Mapping[]>
   local mappings
   mappings = {
      ["yn"] = {
         impl = function(node)
            if node and node.path then
               util.yank_and_notify(node.path)
            end
         end,
         opts = { noremap = true },
         desc = "Yank hierarchical node path",
      },
      ["yv"] = {
         impl = function(node)
            if node and node.value then
               util.yank_and_notify(node.value)
            end
         end,
         opts = { noremap = true },
         desc = "Yank node value",
      },
      ["yf"] = {
         impl = function(node)
            if node and node.instLoc and node.instLoc.uri then
               local uri = string.gsub(node.instLoc.uri, "^file://", "")
               util.yank_and_notify(uri)
            end
         end,
         opts = { noremap = true },
         desc = "Yank enclosing file path",
      },
      ["<cr>"] = {
         impl = function(node)
            if node and node.instLoc then
               util.jump_loc(node.instLoc, M.state.text_winnr)
            end
         end,
         opts = { noremap = true },
         desc = "Jump to node in source",
      },
      ["gd"] = {
         impl = function(node)
            if node and node.declLoc then
               util.jump_loc(node.declLoc, M.state.text_winnr)
            end
         end,
         opts = { noremap = true },
         desc = "Jump to node declaration in source",
      },
      ["<space>"] = {
         impl = function(node)
            if not node then
               return
            end

            if node:is_expanded() and node:collapse() then
               tree:render()
            else
               M._lazy_open(node)
            end
         end,
         opts = { noremap = true },
         desc = "Expand / collapse node",
      },
      ["q"] = {
         impl = function()
            split:unmount()
         end,
         opts = { noremap = true },
         desc = "Close",
      },
      ["?"] = {
         impl = function()
            util.show_help(mappings, "Hierarchy view")
         end,
         opts = { noremap = true },
         desc = "Show help",
      },
   }

   for map, spec in pairs(mappings) do
      split:map("n", map, function()
         spec.impl(tree:get_node())
      end, spec.opts)
   end
end

---@param msg string
---@param opts {parent: NuiTree.Node?, hl: string?}?
local function message(msg, opts)
   local tree = M.state.tree
   if not tree then
      return
   end

   opts = opts or {}
   local id
   if opts.parent then
      id = opts.parent:get_id() .. "__message"
   else
      id = "__message"
   end

   local text = ui.NuiText(msg, opts.hl)

   local msg_node = { ui.NuiTree.Node({ text = text, _uid = id }) }

   if opts.parent then
      tree:set_nodes(msg_node, opts.parent:get_id())
      tree:get_node(opts.parent:get_id()):expand()
   else
      tree:set_nodes(msg_node)
   end

   tree:render()
end

local function on_close()
   if not M.state.open then
      return
   end
   M.state.tree = nil
   M.state.split = nil
   M.state.open = false
end

local function on_hover()
   if not M.state.open then
      return
   end

   if M.state.hover then
      M.state.hover:unmount()
   end

   local selected = M.state.tree:get_node()
   if not (selected and selected.value) then
      return
   end

   M.state.hover = ui.components.hover(selected.value)

   local event = require("nui.utils.autocmd").event
   M.state.hover:on({ event.BufLeave }, function()
      M.state.hover:unmount()
   end, { once = true })

   local line = ui.NuiLine()
   line:append(selected.value, hl.HIER_VALUE)
   line:render(M.state.hover.bufnr, -1, 1)

   M.state.hover:mount()
end

---@param node slang-server.hierarchy.Node
---@param parent_node slang-server.hierarchy.TreeNode?
local function prepare_node(node, parent_node)
   local line = ui.NuiLine()

   if node.text then
      line:append(string.rep(" ", node:get_depth()) .. "└╴", hl.HIER_SUBTLE)
      line:append(" ")
      line:append(node.text, "Comment")
   else
      local decoration = config.kinds[string.lower(node.kind)]
      local expander = " "

      if node.kind == "Instance" or node.kind == "Scope" then
         if node.children and not node:is_expanded() then
            expander = ""
         else
            expander = ""
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

      local box = " "
      if parent_node then
         local last_node = M.state.tree:get_node(parent_node:get_child_ids()[#parent_node:get_child_ids()])
         if last_node then
            box = node:get_id() == last_node:get_id() and " └╴" or " ├╴"
         end
      end

      local hint
      if node.kind == "Instance" and node.declName and node.declName ~= "" then
         hint = node.declName
      elseif node.type and node.type ~= "" then
         hint = node.type
      end

      line:append(string.rep("  ", node:get_depth() - 1) .. box, hl.HIER_SUBTLE)
      line:append(expander, hl.HIER_NORMAL)
      line:append(" " .. decoration.icon, decoration.hl)
      line:append(" " .. node.instName, decoration.hl)
      if hint then
         line:append(" " .. hint, hl.HIER_SUBTLE)
      end
   end

   return line
end

---@param node slang-server.hierarchy.TreeNode
---@return string
local function get_node_id(node)
   return node._uid
end

-- Convert LSP nodes to TreeNodes
---@param nodes slang-server.lsp.Node[]
---@param parent_node slang-server.hierarchy.TreeNode?
---@return slang-server.hierarchy.TreeNode[]
local function parse_nodes(nodes, parent_node)
   local nui_nodes = {}
   local unique_nodes = {}
   for _, node in ipairs(nodes) do
      local treeNode = {}

      local sep = string.match(node.instName, "%[%d+%]") and "" or "."
      treeNode.path = parent_node and (parent_node.path .. sep .. node.instName) or node.instName

      -- Is it possible to have non-unique paths, in cases where Slang can't
      -- statically infer the taken branch of a conditional generate, for
      -- example. We'll use an 'offset' to ensure IDs are unique.
      treeNode._uid = parent_node and (parent_node._uid .. sep .. node.instName) or node.instName
      if unique_nodes[treeNode.path] then
         treeNode._offset = unique_nodes[treeNode.path] + 1
         treeNode._uid = treeNode._uid .. "#" .. treeNode._offset
      end
      unique_nodes[treeNode.path] = treeNode._offset or 0

      if node.children then
         treeNode._populated = #node.children > 0
      else
         treeNode._populated = false
      end

      treeNode = vim.tbl_deep_extend("error", treeNode, node)

      ---@cast treeNode slang-server.hierarchy.TreeNode

      nui_nodes[#nui_nodes + 1] = ui.NuiTree.Node(treeNode, parse_nodes(treeNode.children or {}, treeNode))
   end

   return nui_nodes
end

---@param nodes slang-server.lsp.Node[]
---@param parent slang-server.hierarchy.TreeNode?
---@param root boolean?
local function show_nodes(nodes, parent, root)
   if not M.state.open then
      return
   end

   if root and #nodes > 1 then
      local lines = {}
      for _, node in ipairs(nodes) do
         lines[#lines + 1] = ui.NuiMenu.item(node.instName)
      end

      local menu = ui.components.menu("Select top level instance", {
         lines = lines,
         on_submit = function(item)
            for _, node in ipairs(nodes) do
               if node.instName == item.text then
                  show_nodes({ node }, parent, false)
                  break
               end
            end
         end,
      })

      menu:mount()
      return
   end

   local tree_nodes
   -- If the parent_path is already in the tree, we want to append children to the existing node
   if parent then
      tree_nodes = {}
      for _, node in ipairs(nodes) do
         tree_nodes = vim.tbl_extend("error", tree_nodes, parse_nodes(node.children, parent))
      end
      M.state.tree:set_nodes(tree_nodes, parent:get_id())

      parent:expand()
   else
      tree_nodes = parse_nodes(nodes)
      M.state.tree:set_nodes(tree_nodes)

      for _, node in ipairs(tree_nodes) do
         node:expand()
      end
   end

   M.state.tree:render()
end

-- `path` can be string or nil, with nil representing $root and returning the first top level instance (TODO:)
-- If `path` is given and does not exist in the hierarchy, it is treated as a root node
-- If `path` is given and exists in the hierarchy, it is considered a subscope to be populated
---@param path_or_node slang-server.hierarchy.Path | slang-server.hierarchy.TreeNode
---@param root boolean?
function M._lazy_open(path_or_node, root)
   local node
   local path

   if type(path_or_node) == "string" then
      node = M.state.tree:get_node(path_or_node) --[[@as slang-server.hierarchy.TreeNode?]]
      path = path_or_node
   else
      node = path_or_node
      path = node.path
   end

   -- Don't reload if the node is already populated
   if node and node._populated then
      node:expand()
      M.state.tree:render()
      return
   end

   message("Loading scope...", { parent = node, hl = hl.HIER_SUBTLE })

   client.getScope(M.state.text_bufnr, {
      on_success = function(resp)
         show_nodes(resp, node, root)
      end,
      on_failure = handlers.defaultOnFailure,
   }, { hierPath = path })
end

---@param top slang-server.hierarchy.Path The top level at which to initialise the hierarchy
function M.show(top)
   if M.state.open then
      return
   end

   local hierarchy_config = config.hierarchy
   local split = ui.NuiSplit({
      relative = "win",
      position = hierarchy_config.position,
      size = hierarchy_config.size,
      win_options = {
         signcolumn = "no",
         number = false,
         relativenumber = false,
      },
   })

   local event = require("nui.utils.autocmd").event
   split:on(event.BufUnload, on_close, { once = true })
   split:on(event.CursorMoved, on_hover)

   split:mount()

   vim.api.nvim_buf_set_name(split.bufnr, "Slang-server: Hierarchy")

   local tree = ui.NuiTree({
      prepare_node = prepare_node,
      get_node_id = get_node_id,
      bufnr = split.bufnr,
   })

   map_keys(split, tree)

   M.state.open = true
   M.state.split = split
   M.state.tree = tree

   M._lazy_open(top, true)
end

return M
