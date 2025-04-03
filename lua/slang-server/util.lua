M = {}

---@param loc slang-server.ScopedRange
---@param winnr integer
function M.jump_loc(loc, winnr)
   local win = vim.fn.win_getid(winnr)
   vim.api.nvim_set_current_win(win)
   vim.cmd.edit(loc.uri)

   local start = loc.range.start
   vim.api.nvim_win_set_cursor(win, { start.line + 1, start.character })
end

---@param mappings slang-server.UiMapping[]
---@param title string?
---@param opts table?
function M.show_help(mappings, title, opts)
   local NuiPopup = require("nui.popup")
   local NuiLine = require("nui.line")

   local hl = require("slang-server._core.highlights")

   opts = vim.tbl_deep_extend("force", {
      position = "50%",
      relative = "editor",
      size = {
         width = 50,
         height = #mappings,
      },
      border = {
         style = "rounded",
         padding = { 1, 2 },
         text = {
            top = title and (" " .. title .. " ") or nil,
            top_align = "center",
            bottom = " q: quit ",
            bottom_align = "center",
         },
      },
      enter = true,
      focusable = true,
      buf_options = {
         modifiable = false,
         readonly = true,
      },
      win_options = {
         winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
      },
   }, opts or {})

   local popup = NuiPopup(opts)

   local event = require("nui.utils.autocmd").event
   popup:on({ event.BufLeave }, function()
      popup:unmount()
   end, { once = true })

   popup:map("n", "q", function()
      popup:unmount()
   end, { noremap = true })

   popup:map("n", "?", function()
      popup:unmount()
   end, { noremap = true })

   local max = 0
   for _, map in ipairs(mappings) do
      max = math.max(max, string.len(map.map))
   end
   local fmt = string.gsub("%-_._s", "_", max)

   for i, map in ipairs(mappings) do
      local line = NuiLine()
      line:append(string.format(fmt, map.map) .. " : " .. map.desc, hl.HIER_SUBTLE)

      line:render(popup.bufnr, -1, i)
   end

   popup:mount()
end
return M
