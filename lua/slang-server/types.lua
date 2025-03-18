
---@class (exact) slang-server.Configuration
---    The user's slang-server configuration
---@field kinds slang-server.ConfigurationKinds?
---@field highlights slang-server.ConfigurationHighlights?
---@field hierarchy slang-server.ConfigurationHierarchy?

---@class (exact) slang-server.ConfigurationHierarchy
---@field position string?
---@field size integer?

---@class (exact) slang-server.ConfigurationKinds
---@field instance slang-server.ConfigurationKindScoped?
---@field scope slang-server.ConfigurationKindScoped?
---@field port slang-server.ConfigurationKind?
---@field param slang-server.ConfigurationKind?
---@field reg slang-server.ConfigurationKind?

---@class (exact) slang-server.ConfigurationKind
---@field icon string?
---@field hl string?

---@class (exact) slang-server.ConfigurationKindScoped
---@field open slang-server.ConfigurationKind?
---@field closed slang-server.ConfigurationKind?

---@alias slang-server.ConfigurationHighlights table<string, vim.api.keyset.highlight>

---@alias slang-server.HierarchyPath string
