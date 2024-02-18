# autocomplete.nvim
Very simple and minimal autocompletion for cmdline and LSP with signature help.  

Originally I made this just for my dotfiles as I did not needed most of stuff existing plugins provided I had
some issues with the ones that were close to what I wanted so as a learning exercise I decided to try and
implement it by myself. Then I just extracted the code to separate plugin in case anyone else wanted to use it too.
Just a warning, there might be some bugs and as this requires Neovim 0.10+ (e.g nightly), that one can also have
bugs by itself.

LSP documentation:
![lsp-documentation](https://github.com/deathbeam/autocomplete.nvim/assets/5115805/92a4a56e-4156-439e-bc24-8ebad0bc7e2b)

LSP signature help:
![lsp-signature-help](https://github.com/deathbeam/autocomplete.nvim/assets/5115805/40a5fb51-8506-4f22-8da2-210f44bee2d5)

cmdline completion:
![cmd-completion](https://github.com/deathbeam/autocomplete.nvim/assets/5115805/26032cf7-fe39-4a78-9745-ab1599fe8d14)

## Requirements

Requires **Neovim Nighly/development** version. This version supports stuff like popup menu
for completion menu and closing windows properly from cmdline callbacks.  

For installation instructions/repository go [here](https://github.com/neovim/neovim)

## Installation

Just use [lazy.nvim](https://github.com/folke/lazy.nvim) or `:h packages` with git submodules or something else I don't care.
Read the documentation of whatever you want to use.

## Usage

Just require either lsp or cmd module or both and call setup on them.  
**NOTE**: You dont need to provide the configuration, below is just default config, you can just
call setup with no arguments for default.

```lua
-- LSP signature help
require("autocomplete.signature").setup {
    border = nil, -- Signature help border style
    max_width = nil, -- Max width of signature window
    debounce_delay = 100
}

-- LSP autocompletion
require("autocomplete.lsp").setup {
    server_side_filtering = true, -- Use LSP filtering instead of vim's
    debounce_delay = 100
}

-- cmdline autocompletion
require("autocomplete.cmd").setup {
    mappings = {
        accept = '<C-y>',
        reject = '<C-e>',
        complete = '<C-space>',
        next = '<C-n>',
        previous = '<C-p>',
    },
    border = nil, -- Cmdline completion border style
    columns = 5, -- Number of columns per row
    rows = 0.3, -- Number of rows, if < 1 then its fraction of total vim lines, if > 1 then its absolute number
    close_on_done = true, -- Close completion window when done (accept/reject)
    debounce_delay = 100,
}
```

You also probably want to enable `popup` in completeopt to show documentation preview:

```lua
vim.o.completeopt = 'menuone,noinsert,popup'
```

If you want to disable `<CR>` to accept completion (as with autocomplete its disgustingly annoying) you can do this:

```lua
-- Disable <CR> to accept (this really should be a mapping, so stupid)
vim.keymap.set("i", "<CR>", function()
    return vim.fn.pumvisible() ~= 0 and "<Esc>o" or "<CR>"
end, { expr = true, replace_keycodes = true })
```

And you also ideally want to set the capabilities so Neovim will fetch documentation and additional text edits
when resolving completion items:

```lua
-- Here we grab default Neovim capabilities and extend them with ones we want on top
local capabilities = vim.tbl_deep_extend('force', 
    vim.lsp.protocol.make_client_capabilities(), 
    require('completion.lsp').capabilities)

-- Now set capabilities on your LSP servers
require('lspconfig')['<YOUR_LSP_SERVER>'].setup {
    capabilities = capabilities
}
```

## Similar projects

I used some of this projects as reference and they are also good alternatives:

- https://github.com/nvimdev/epo.nvim
- https://github.com/hrsh7th/nvim-cmp
- https://github.com/smolck/command-completion.nvim
- https://github.com/gelguy/wilder.nvim
