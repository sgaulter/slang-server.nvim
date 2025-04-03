local cmdparser = require("mega.cmdparse")

local _PREFIX = "SlangServer"

---@type mega.cmdparse.ParserCreator
local _SUBCOMMANDS = function()
   local hierarchy = require("slang-server._commands.hierarchy")
   local openWaveform = require("slang-server._commands.openWaveform")
   local addToWaves = require("slang-server._commands.addToWaves")

   local parser = cmdparser.ParameterParser.new({ name = _PREFIX, help = "SlangServer" })
   local subparsers = parser:add_subparsers({ "commands", help = "All subcommands" })

   subparsers:add_parser(hierarchy.make_parser())
   subparsers:add_parser(openWaveform.make_parser())
   subparsers:add_parser(addToWaves.make_parser())

   return parser
end

cmdparser.create_user_command(_SUBCOMMANDS, _PREFIX)
