local M = {}

---@type slang-server.Configuration
M.CONFIG = {}

vim.g.loaded_slang_server = false

---@type slang-server.Configuration
local default_config = {
	kinds = {
		instance = {
			open = { icon = "I", hl = "SlangServerInstance" },
			closed = { icon = "i", hl = "SlangServerInstance" },
		},
		scope = {
			open = { icon = "S", hl = "SlangServerScope" },
			closed = { icon = "s", hl = "SlangServerScope" },
		},
		port = { icon = "P", hl = "SlangServerPort" },
		param = { icon = "A", hl = "SlangServerParam" },
		reg = { icon = "R", hl = "SlangServerReg" },
	},
	highlights = {
		SlangServerHierarchyTop = {
			fg = "#f65866",
			bold = true,
		},
		SlangServerInstance = { fg = "#efbd5d" },
		SlangServerScope = { fg = "#41a7fc" },
		SlangServerPort = { fg = "#93a4c3" },
		SlangSererParam = { fg = "#93a4c3" },
		SlangServerReg = { fg = "#93a4c3" },
	},
}

M.initialise = function()
	if not vim.g.loaded_slang_server then
		M.update(default_config)
		M.update(vim.g.slang_server_config)

		vim.g.loaded_slang_server = true
	end
end

---@param opts slang-server.Configuration?
M.update = function(opts)
	M.CONFIG = vim.tbl_deep_extend("force", M.CONFIG, opts or {})
end

return M
