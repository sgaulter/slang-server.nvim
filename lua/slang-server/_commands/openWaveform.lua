-- Parser for :SlangServer openWaveform

local cmdparse = require("mega.cmdparse")
local client = require("slang-server._lsp.client")

local M = {}

---@return mega.cmdparse.ParameterParser
function M.make_parser()
   local parser = cmdparse.ParameterParser.new({ "openWaveform", help = "Open a waveform file via slang-server" })

   parser:add_parameter({
      "file",
      required = false,
      help = "The waveform file",
   })

   parser:set_execute(function(data)
      ---@cast data mega.cmdparse.NamespaceExecuteArguments
      M.run(data.namespace.file)
   end)

   return parser
end

---@param file string
function M.run(file)
   client.openWaveform(vim.api.nvim_get_current_buf(), {
      on_success = function(_) end,
      on_failure = function(msg)
         vim.notify(msg, vim.log.levels.ERROR)
      end,
   }, { uri = file })
end

return M
