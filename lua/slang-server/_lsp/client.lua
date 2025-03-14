local M = {}

---@alias SourceLoc integer[]
---@alias SourceRange { ["start"]: Loc, ["end"]: Loc }

---@enum SlangKind
SlangKind = {
	INSTANCE = 0,
	PORT = 1,
	PARAM = 2,
	REG = 3,
	SCOPE = 4,
}

M.kind_map = {
	[SlangKind.INSTANCE] = "instance",
	[SlangKind.SCOPE] = "scope",
	[SlangKind.PARAM] = "param",
	[SlangKind.PORT] = "port",
	[SlangKind.REG] = "reg",
}

---@class slang_server.Item
---@field kind SlangKind
---@field instName string
---@field instLoc SourceLoc

---@class slang_server.Var : slang_server.Item
---@field type string

---@class slang_server.Param : slang_server.Var
---@field value string

---@class slang_server.Scope : slang_server.Item
---@field children slang_server.Item[]

---@class slang_server.Instance : slang_server.Item
---@field declName string
---@field declLoc SourceLoc

---@class slang_server.FilledInstance : slang_server.Scope, slang_server.Instance

---@alias slang_server.Node slang_server.Item | slang_server.Var | slang_server.Scope | slang_server.FilledInstance

---@alias RespHandlers {on_success: fun(resp: any), on_failure?: fun(message: string)}

-- LSP commands
---@param bufnr integer
---@param params lsp.ExecuteCommandParams
---@param handlers RespHandlers
local lsp_execute = function(bufnr, params, handlers)
	local command = "workspace/executeCommand"

	local on_failure = handlers.on_failure or function() end

	local client_found = false
	for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if
			client.server_capabilities.executeCommandProvider
			and client.server_capabilities.executeCommandProvider.commands[command]
		then
			client_found = true
			break
		end
	end

	if not client_found then
		on_failure("No client found")
		return
	end

	local handle = function(resp)
		for _, client_resp in pairs(resp) do
			if resp.error then
				on_failure(resp.error.message)
				return
			else
				handlers.on_success(client_resp.result)
			end
		end
	end

	vim.lsp.buf_request_all(bufnr, command, params, handle)
end

---@param bufnr integer
---@param handlers RespHandlers
---@param params { uri: string }
M.setTopLevel = function(bufnr, handlers, params)
	lsp_execute(bufnr, {
		command = "slang.setTopLevel",
		arguments = params,
	}, handlers)
end

---@param bufnr integer
---@param handlers RespHandlers
---@param params { uri: string }
M.setBuildFile = function(bufnr, handlers, params)
	lsp_execute(bufnr, {
		command = "slang.setBuildFile",
		arguments = params,
	}, handlers)
end

---@param bufnr integer
---@param handlers RespHandlers
---@param params { hierPath: string }
M.getScope = function(bufnr, handlers, params)
	lsp_execute(bufnr, {
		command = "slang.getScope",
		arguments = params,
	}, handlers)
end

---@param bufnr integer
---@param handlers RespHandlers
---@param params { hierPath: string }
M.getScopes = function(bufnr, handlers, params)
	lsp_execute(bufnr, {
		command = "slang.getScopes",
		arguments = params,
	}, handlers)
end

---@param bufnr integer
---@param handlers RespHandlers
M.getScopesByModule = function(bufnr, handlers)
	lsp_execute(bufnr, {
		command = "slang.getScopesByModule",
	}, handlers)
end

return M
