local M = {}

local severity_order = {
  [vim.diagnostic.severity.ERROR] = 1,
  [vim.diagnostic.severity.WARN]  = 2,
  [vim.diagnostic.severity.INFO]  = 3,
  [vim.diagnostic.severity.HINT]  = 4,
}

local severity_char = {
  [vim.diagnostic.severity.ERROR] = 'E',
  [vim.diagnostic.severity.WARN]  = 'W',
  [vim.diagnostic.severity.INFO]  = 'I',
  [vim.diagnostic.severity.HINT]  = 'H',
}

local char_to_severity = {
  E = vim.diagnostic.severity.ERROR,
  W = vim.diagnostic.severity.WARN,
  I = vim.diagnostic.severity.INFO,
  H = vim.diagnostic.severity.HINT,
}

M.severity_chars = { 'E', 'W', 'I', 'H' }

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
