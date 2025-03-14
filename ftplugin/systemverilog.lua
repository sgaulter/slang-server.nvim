local cmdparser = require("mega.cmdparse")

local _PREFIX = "SlangServer"

---@type mega.cmdparse.ParserCreator
local _SUBCOMMANDS = function()
	local hierarchy = require("slang-server._commands.hierarchy")

	local parser = cmdparser.ParameterParser.new({ name = _PREFIX, help = "SlangServer" })
	local subparsers = parser:add_subparsers({ "commands", help = "All subcommands" })

	subparsers:add_parser(hierarchy.make_parser())

	return parser
end

cmdparser.create_user_command(_SUBCOMMANDS, _PREFIX)
