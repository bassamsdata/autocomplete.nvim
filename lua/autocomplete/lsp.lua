local util = require('autocomplete.util')
local methods = vim.lsp.protocol.Methods

local M = {}

local state = {
    skip_next = false
}

local function complete_done(client, bufnr)
    local item = vim.tbl_get(vim.v, 'completed_item', 'user_data', 'nvim', 'lsp', 'completion_item')
    if not item then
        return
    end

    if vim.tbl_isempty(item.additionalTextEdits or {}) then
        util.debounce('textEdits', M.config.debounce_delay, function()
            return util.request(client, methods.completionItem_resolve, item, function(_, result)
                if not vim.tbl_isempty(result.additionalTextEdits or {}) then
                    vim.lsp.util.apply_text_edits(result.additionalTextEdits, bufnr, client.offset_encoding)
                end
            end, bufnr)
        end)
    else
        vim.lsp.util.apply_text_edits(item.additionalTextEdits, bufnr, client.offset_encoding)
    end

    state.skip_next = true
end

local function complete_changed(client, bufnr)
    local item = vim.tbl_get(vim.v.event, 'completed_item', 'user_data', 'nvim', 'lsp', 'completion_item')
    if not item then
        return
    end

    -- FIXME: Sometimes I do not receive updated complete_info (for example requests.get, 
    -- I get index 19 instead of 0 as its only match, when I press backspace it updates to 0)
    local data = vim.fn.complete_info()
    local selected = data.selected

    util.debounce('info', M.config.debounce_delay, function()
        return util.request(client, methods.completionItem_resolve, item, function(_, result)
            local info = vim.fn.complete_info()

            -- FIXME: Preview popup do not auto resizes to fit new content so have to reset it like this
            if info.preview_winid and vim.api.nvim_win_is_valid(info.preview_winid) then
                vim.api.nvim_win_close(info.preview_winid, true)
            end

            if
                not result
                or not info.items
                or not info.selected
                or not info.selected == selected
            then
                return
            end

            local value = vim.tbl_get(result, 'documentation', 'value')
            if value then
                local wininfo = vim.api.nvim_complete_set(selected, { info = value })
                if wininfo.winid and wininfo.bufnr then
                    vim.wo[wininfo.winid].conceallevel = 2
                    vim.wo[wininfo.winid].concealcursor = 'niv'
                    vim.bo[wininfo.bufnr].syntax = 'markdown'
                end
            end
        end, bufnr)
    end)
end

local function completion_handler(client, line, col, result, ctx)
    local cmp_start = vim.fn.match(line:sub(1, col), '\\k*$')
    local prefix = line:sub(cmp_start + 1, col)
    local items = vim.lsp._completion._lsp_to_complete_items(result, prefix)
    items = vim.tbl_filter(function (item) return item.kind ~= "Snippet" end, items)
    vim.schedule(function()
        if vim.fn.mode() == 'i' then
            vim.fn.complete(cmp_start + 1, items)
        end
    end)
end

local function text_changed(client, bufnr)
    -- We do not want to trigger completion again if we just accepted a completion
    if state.skip_next then
        state.skip_next = false
        return
    end

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    if col == 0 or #line == 0 then
        return
    end

    local char = line:sub(col, col)
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)


    -- Check if we are triggering completion automatically or on trigger character
    if vim.tbl_contains(client.server_capabilities.completionProvider.triggerCharacters or {}, char) then
        params.context = {
            triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter,
            triggerCharacter = char
        }
    else
        params.context = {
            triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked,
            triggerCharacter = ''
        }
    end

    util.debounce('completion', M.config.debounce_delay, function()
        return util.request(client, methods.textDocument_completion, params, util.handle(client, line, col, completion_handler), bufnr)
    end)
end

M.config = {
    debounce_delay = 100
}

function M.capabilities()
    return {
        textDocument = {
            completion = {
                completionItem = {
                    -- Fetch additional info for completion items
                    resolveSupport = {
                        properties = {
                            'documentation',
                            'detail',
                            'additionalTextEdits'
                        },
                    },
                }
            },
        },
    }
end

function M.setup(config)
    M.config = vim.tbl_deep_extend('force', M.config, config or {})
    local group = vim.api.nvim_create_augroup('LspCompletion', {})

    vim.api.nvim_create_autocmd('TextChangedI', {
        desc = 'Auto show LSP completion',
        group = group,
        callback = util.with_client(text_changed, methods.textDocument_completion)
    })

    vim.api.nvim_create_autocmd('CompleteDone', {
        desc = 'Auto apply LSP completion edits after selection',
        group = group,
        callback = util.with_client(complete_done, methods.textDocument_completion)
    })

    vim.api.nvim_create_autocmd('CompleteChanged', {
        desc = 'Auto update LSP completion info',
        group = group,
        callback = util.with_client(complete_changed, methods.textDocument_completion)
    })
end

return M
