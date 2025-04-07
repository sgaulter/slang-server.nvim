local NuiText = require("nui.text")
local NuiLine = require("nui.line")
local NuiMenu = require("nui.menu")
local NuiSplit = require("nui.split")
local NuiTree = require("nui.tree")
local NuiPopup = require("nui.popup")
local client = require("slang-server._lsp.client")
local handlers = require("slang-server.handlers")
local highlights = require("slang-server._core.highlights")
local config = require("slang-server._core.config").CONFIG
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
   ---@type slang-server.ui.Mapping[]
   local mappings
   mappings = {
      {
         mode = "n",
         map = "y",
         fn = function()
            local node = tree:get_node()
            if not node then
               return
            end

            vim.fn.setreg("+", node.path) --TODO: default register

            vim.notify("Yanked " .. node.path, vim.log.levels.INFO)
         end,
         opts = { noremap = true },
         desc = "Yank hierarchical node path",
      },
      {
         mode = "n",
         map = "v",
         fn = function()
            local node = tree:get_node()
            if not (node and node.value) then
               return
            end

            vim.fn.setreg("+", node.value) --TODO: default register

            vim.notify("Yanked " .. node.value, vim.log.levels.INFO)
         end,
         opts = { noremap = true },
         desc = "Yank node value",
      },
      {
         mode = "n",
         map = "<cr>",
         fn = function()
            local node = tree:get_node()
            if not (node and node.instLoc) then
               return
            end

            util.jump_loc(node.instLoc, M.state.text_winnr)
         end,
         opts = { noremap = true },
         desc = "Jump to node in source",
      },
      {
         mode = "n",
         map = "gd",
         fn = function()
            local node = tree:get_node()
            if not (node and node.declLoc) then
               return
            end
            util.jump_loc(node.declLoc, M.state.text_winnr)
         end,
         opts = { noremap = true },
         desc = "Jump to node declaration in source",
      },
      {
         mode = "n",
         map = "<space>",
         fn = function()
            local node = tree:get_node() --[[@as slang-server.hierarchy.TreeNode]]

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
      {
         mode = "n",
         map = "q",
         fn = function()
            split:unmount()
         end,
         opts = { noremap = true },
         desc = "Close",
      },
      {
         mode = "n",
         map = "?",
         fn = function()
            util.show_help(mappings, "Hierarchy view")
         end,
         opts = { noremap = true },
         desc = "Show help",
      },
   }

   for _, map in ipairs(mappings) do
      split:map(map.mode, map.map, map.fn, map.opts)
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

   local text = NuiText(msg, opts.hl)

   local msg_node = { NuiTree.Node({ text = text, _uid = id }) }

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

   M.state.hover = NuiPopup({
      enter = false,
      focusable = false,
      size = {
         width = string.len(selected.value),
         height = 1,
      },
      relative = "cursor",
      position = {
         row = 1,
         col = 0,
      },
      border = {
         style = "none",
         padding = { 0, 1 },
      },
   })
   local event = require("nui.utils.autocmd").event
   M.state.hover:on({ event.BufLeave }, function()
      M.state.hover:unmount()
   end, { once = true })

   local line = NuiLine()
   line:append(selected.value, highlights.HIER_VALUE)
   line:render(M.state.hover.bufnr, -1, 1)

   M.state.hover:mount()
end

---@param node slang-server.hierarchy.Node
---@param parent_node slang-server.hierarchy.TreeNode?
local function prepare_node(node, parent_node)
   local line = NuiLine()

   if node.text then
      line:append(string.rep(" ", node:get_depth()) .. "└╴", highlights.HIER_SUBTLE)
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

      line:append(string.rep("  ", node:get_depth() - 1) .. box, highlights.HIER_SUBTLE)
      line:append(expander, highlights.HIER_NORMAL)
      line:append(" " .. decoration.icon, decoration.hl)
      line:append(" " .. node.instName, decoration.hl)
      if hint then
         line:append(" " .. hint, highlights.HIER_SUBTLE)
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

      nui_nodes[#nui_nodes + 1] = NuiTree.Node(treeNode, parse_nodes(treeNode.children or {}, treeNode))
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
         lines[#lines + 1] = NuiMenu.item(node.instName)
      end
      local menu = NuiMenu({
         position = "50%",
         relative = "editor",
         border = {
            style = "single",
            padding = { 1, 2 },
            text = { top = "[Select top level instance]", top_align = "center" },
         },
      }, {
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

   message("Loading scope...", { parent = node, hl = highlights.HIER_SUBTLE })

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
   local split = NuiSplit({
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

   local tree = NuiTree({
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
