local M = {}

M.defaultOnSuccess = function(_) end

---@param msg string
M.defaultOnFailure = function(msg)
   vim.notify(msg, vim.log.level.ERROR)
end

M.defaultHandlers = {
   on_success = M.defaultOnSuccess,
   on_failure = M.defaultOnFailure,
}

return M
