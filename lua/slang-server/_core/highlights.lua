local M = {}

M.ns_id = vim.api.nvim_create_namespace("SlangServer")

M.HIER_TOP = "SlangServerHierarchyTop"
M.HIER_INSTANCE = "SlangServerInstance"
M.HIER_SCOPE = "SlangServerScope"
M.HIER_PORT = "SlangServerPort"
M.HIER_PARAM = "SlangServerParam"
M.HIER_REG = "SlangServerReg"

M.setup = function(config)
	for hl_name, hl_opts in pairs(config.highlights) do
		vim.api.nvim_set_hl(M.ns_id, hl_name, hl_opts)
	end
end

return M
