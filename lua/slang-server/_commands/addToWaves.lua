-- Parser for :SlangServer openWaveform

local M = {}

---@type slang-server.ui.Subcommand
M.addToWaves = {
   impl = function(args)
      local client = require("slang-server._lsp.client")
      local handlers = require("slang-server.handlers")
      local ui = require("slang-server._core.ui")

      local recursive = args[1] == "true"

      local bufnr = vim.api.nvim_get_current_buf()

      client.getInstances(bufnr, {
         on_success = function(resp)
            if resp == nil or next(resp) == nil then
               vim.notify("No instances to add", vim.log.levels.WARN)
               return
            end
            if #resp == 1 then
               client.addToWaveform(bufnr, handlers.defaultHandlers, { inst = resp[1], recursive = recursive })
            else
               local lines = {}
               for i = 1, #resp do
                  table.insert(lines, ui.NuiMenu.item(resp[i].path, { inst = resp[i] }))
               end
               local menu = ui.components.menu("Add instance to waves", {
                  lines = lines,
                  on_submit = function(item)
                     client.addToWaveform(bufnr, handlers.defaultHandlers, { inst = item.inst, recursive = recursive })
                  end,
               })
               menu:mount()
            end
         end,
         on_failure = handlers.defaultOnFailure,
      }, { position = vim.lsp.util.make_position_params() })
   end,
}

return M
