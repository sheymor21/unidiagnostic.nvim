local M = {}

M.defaults = {
  -- Window position
  position = 'center',       -- 'center' | 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right'
  width = 80,
  height = 20,
  border = 'rounded',

  -- Navigation keys (Colemak-friendly by default, user can override)
  keys = {
    up = 'k',        -- move up
    down = 'j',      -- move down
    open = '<CR>',   -- jump to diagnostic
    close = 'q',     -- close window
  },

  -- Behavior
  auto_refresh = true,
  severity_sort = true, -- Error > Warn > Info > Hint

  -- Reserved for future scanner (ignored now)
  scanner = {
    enabled = false,
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', M.defaults, opts or {})
end

function M.get()
  return M.options
end

return M
