-- Parser for :SlangServer hierarchy

local M = {}

---@type slang-server.UiSubcommand
M.hierarchy = {
   impl = function(args, opts)
      local top = args[1]
      require("slang-server.hierarchy").show(top)
   end,
}

return M
