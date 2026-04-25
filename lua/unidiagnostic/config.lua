local M = {}

M.defaults = {
  -- Window position
  position = 'center',       -- 'center' | 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right'
  width = 80,
  height = 20,
  border = 'rounded',

  -- Navigation keys (user can override)
  keys = {
    open = '<CR>',   -- jump to diagnostic
    close = 'q',     -- close window
    fold = 'h',      -- toggle fold / retract file
    search = 's',    -- telescope search diagnostics in file under cursor
    search_all = 'S', -- telescope search all diagnostics
  },

  -- Window highlights to blend with editor (nil = Neovim defaults)
  winhighlight = 'Normal:Normal,FloatBorder:VertSplit,FloatTitle:Title',

  -- Behavior
  auto_refresh = true,
  severity_sort = true, -- Error > Warn > Info > Hint
  fold_by_default = true, -- start with all file groups collapsed

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
