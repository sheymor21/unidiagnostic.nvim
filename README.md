# unidiagnostic.nvim

A simple, Colemak-friendly Neovim plugin to view all LSP / built-in diagnostics in a floating window.

## Features

- **All buffers**: Shows diagnostics from all open buffers
- **Grouped by file**: Diagnostics are grouped under their file path
- **Severity sorted**: Errors first, then warnings, info, hints
- **Colemak-friendly**: Configurable navigation keys
- **Auto-refresh**: Updates automatically when diagnostics change or on save
- **Jump to error**: Press `<CR>` on any diagnostic to jump directly to it
- **Customizable position**: Center (default), or any corner of the screen

## Installation

### lazy.nvim
```lua
{
  'sheymor/unidiagnostic.nvim',
  config = function()
    require('unidiagnostic').setup()
  end,
}
```

### packer.nvim
```lua
use {
  'sheymor/unidiagnostic.nvim',
  config = function()
    require('unidiagnostic').setup()
  end,
}
```

## Configuration

```lua
require('unidiagnostic').setup({
  -- Window position
  position = 'center',       -- 'center' | 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right'
  width = 80,
  height = 20,
  border = 'rounded',

  -- Navigation keys (Colemak-friendly by default, fully customizable)
  keys = {
    up    = 'k',    -- move up
    down  = 'j',    -- move down
    open  = '<CR>', -- jump to diagnostic location
    close = 'q',    -- close window
  },

  -- Behavior
  auto_refresh   = true,
  severity_sort  = true, -- Error > Warn > Info > Hint
})
```

## Usage

| Command | Description |
|---------|-------------|
| `:UnidiagnosticToggle` | Open or close the diagnostic window |
| `:UnidiagnosticRefresh` | Manually refresh the window content |

## Display Format

```
lua/plugins/init.lua
  [E]  12:5   Undefined variable 'foo'
  [W]  45:2   Unused local 'bar'

src/core/engine.ts
  [E]  3:1    Cannot find name 'console'
```

- `[E]` / `[W]` / `[I]` / `[H]` — colored by severity
- `line:column` — exact position
- Message — the diagnostic text

## Future: Project Scanner

The architecture includes a reserved `scanner` config section. In the future, this will allow running external tools (e.g., `eslint`, `tsc`, `cargo check`) to populate diagnostics for unopened files, giving true project-wide coverage beyond what LSP provides.

## License

MIT
