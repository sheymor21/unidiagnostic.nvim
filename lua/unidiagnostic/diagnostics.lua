local config = require('unidiagnostic.config')

local M = {}

local severity_map = {
  [vim.diagnostic.severity.ERROR] = 'E',
  [vim.diagnostic.severity.WARN]  = 'W',
  [vim.diagnostic.severity.INFO]  = 'I',
  [vim.diagnostic.severity.HINT]  = 'H',
}

local severity_order = {
  [vim.diagnostic.severity.ERROR] = 1,
  [vim.diagnostic.severity.WARN]  = 2,
  [vim.diagnostic.severity.INFO]  = 3,
  [vim.diagnostic.severity.HINT]  = 4,
}

---@class DiagnosticItem
---@field bufnr number
---@field lnum number
---@field col number
---@field message string
---@field severity number
---@field source string|nil
---@field code string|nil
---@field filepath string

--- Gather all diagnostics from vim.diagnostic.get()
--- Future hook: scanner module can be added here
function M.gather()
  local all = vim.diagnostic.get()

  -- TODO: Future scanner integration
  -- if config.get().scanner.enabled then
  --   local scanned = require('unidiagnostic.scanner').run()
  --   vim.list_extend(all, scanned)
  -- end

  ---@type DiagnosticItem[]
  local items = {}
  for _, d in ipairs(all) do
    local filepath = vim.api.nvim_buf_get_name(d.bufnr)
    if filepath == '' then
      filepath = '[No Name]'
    end

    table.insert(items, {
      bufnr = d.bufnr,
      lnum = d.lnum + 1,    -- 0-indexed to 1-indexed
      col = d.col + 1,
      message = d.message or '',
      severity = d.severity or vim.diagnostic.severity.ERROR,
      source = d.source,
      code = d.code,
      filepath = filepath,
    })
  end

  -- Sort by severity if enabled
  if config.get().severity_sort then
    table.sort(items, function(a, b)
      local sa = severity_order[a.severity] or 99
      local sb = severity_order[b.severity] or 99
      if sa ~= sb then
        return sa < sb
      end
      if a.filepath ~= b.filepath then
        return a.filepath < b.filepath
      end
      if a.lnum ~= b.lnum then
        return a.lnum < b.lnum
      end
      return a.col < b.col
    end)
  end

  return items
end

function M.get_severity_char(severity)
  return severity_map[severity] or '?'
end

return M
