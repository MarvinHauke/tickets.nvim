# Installation

Tickets.nvim requires **Neovim >= 0.8.0** and depends on [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

## using lazy.nvim

```lua
{
    "MarvinHauke/tickets.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        require("tickets").setup({
            -- Your configuration here
        })
    end
}
```

## using packer.nvim

```lua
use {
    "MarvinHauke/tickets.nvim",
    requires = { "nvim-lua/plenary.nvim" },
    config = function()
        require("tickets").setup()
    end
}
```

## using vim-plug

```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'MarvinHauke/tickets.nvim'

" After plug#end()
lua require("tickets").setup()
```
