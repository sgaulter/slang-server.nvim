-- Parser for :SlangServer hierarchy

local cmdparse = require("mega.cmdparse")

local M = {}

---@return mega.cmdparse.ParameterParser
function M.make_parser()
   local parser = cmdparse.ParameterParser.new({ "hierarchy", help = "Open the module hierarchy view" })

   parser:add_parameter({
      "top",
      required = false,
      help = "The top level at which to initialise the hierarchy view. Defaults to current module.",
   })

   parser:set_execute(function(data)
      ---@cast data mega.cmdparse.NamespaceExecuteArguments
      M.run(data.namespace.top)
   end)

   return parser
end

---@param top slang-server.hierarchy.Path?
function M.run(top)
   require("slang-server.hierarchy").show(top)
end

return M
