local M = {}

local severity_order = {
  [vim.diagnostic.severity.ERROR] = 1,
  [vim.diagnostic.severity.WARN]  = 2,
  [vim.diagnostic.severity.INFO]  = 3,
  [vim.diagnostic.severity.HINT]  = 4,
}

local severity_char = {
  [vim.diagnostic.severity.ERROR] = 'e',
  [vim.diagnostic.severity.WARN]  = 'w',
  [vim.diagnostic.severity.INFO]  = 'i',
  [vim.diagnostic.severity.HINT]  = 's',
}

local char_to_severity = {
  e = vim.diagnostic.severity.ERROR,
  w = vim.diagnostic.severity.WARN,
  i = vim.diagnostic.severity.INFO,
  s = vim.diagnostic.severity.HINT,
}

M.severity_chars = { 'e', 'w', 'i', 's' }

--- Get severity sort order (lower = higher priority)
---@param severity number
---@return number
function M.severity_order(severity)
  return severity_order[severity] or 99
end

--- Get single-char severity representation
---@param severity number
---@return string
function M.get_severity_char(severity)
  return severity_char[severity] or '?'
end

--- Convert severity char back to severity level
---@param char string
---@return number|nil
function M.char_to_severity(char)
  return char_to_severity[char]
end

--- Get highlight group for a severity level
---@param severity number
---@return string
function M.severity_to_hl(severity)
  if severity == vim.diagnostic.severity.ERROR then
    return 'DiagnosticError'
  elseif severity == vim.diagnostic.severity.WARN then
    return 'DiagnosticWarn'
  elseif severity == vim.diagnostic.severity.INFO then
    return 'DiagnosticInfo'
  elseif severity == vim.diagnostic.severity.HINT then
    return 'DiagnosticHint'
  end
  return 'Normal'
end

return M
