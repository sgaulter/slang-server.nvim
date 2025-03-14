-- Parser for :SlangServer hierarchy

local cmdparse = require("mega.cmdparse")

local M = {}

---@return mega.cmdparse.ParameterParser
function M.make_parser()
	local parser = cmdparse.ParameterParser.new({ "hierarchy", help = "Open the module hierarchy view" })


	parser:set_execute(function(data)
		---@cast data mega.cmdparse.NamespaceExecuteArguments

    -- TODO: arguments?
		-- local names = {}
		-- for _, argument in ipairs(data.input.arguments) do
		-- 	table.insert(names, argument.name)
		-- end

		M.run()
	end)

	return parser
end

function M.run()
	require("slang-server.hierarchy").open()
end


return M
