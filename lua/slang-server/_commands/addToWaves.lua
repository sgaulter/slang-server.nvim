-- Parser for :SlangServer openWaveform

local M = {}

---@type slang-server.UiSubcommand
M.addToWaves = {
   impl = function(args)
      local client = require("slang-server._lsp.client")
      local handlers = require("slang-server.handlers")
      local NuiMenu = require("nui.menu")

      local bufnr = vim.api.nvim_get_current_buf()

      client.getInstances(bufnr, {
         on_success = function(resp)
            if resp == nil or next(resp) == nil then
               vim.notify("No instances to add", vim.log.levels.WARN)
               return
            end
            if #resp == 1 then
               -- TODO -- scopes
               client.variableToWaveform(bufnr, handlers.defaultHandlers, { hierPath = resp[1].path })
            else
               local lines = {}
               for i = 1, #resp do
                  table.insert(lines, NuiMenu.item(resp[i].path, { inst = resp[i] }))
               end
               local menu = NuiMenu({
                  position = "50%",
                  border = {
                     style = "single",
                     padding = { 1, 2 },
                     text = {
                        top = "[Add Instance to Waves]",
                        top_align = "center",
                     },
                  },
                  win_options = {
                     winhighlight = "Normal:Normal,FloatBorder:Normal",
                  },
               }, {
                  lines = lines,
                  on_submit = function(item)
                     client.variableToWaveform(bufnr, handlers.defaultHandlers, { hierPath = item.inst.path })
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
