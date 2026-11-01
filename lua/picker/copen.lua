---@brief Route `:copen` and `:lopen` through the `quickfix` and `loclist`
---sources. Enabled by `replace_copen` and `replace_lopen`; see
---`picker.Config`.

local M = {}

local config = require("picker.config").current

local _AUGROUP = "PickerCopen"

---Close the native window and open the picker in its place.
---
---This runs after the `BufWinEnter` event has finished, not from inside it:
---closing the window mid-event would leave the event's other handlers running
---in whatever window took the closed one's place, and would swallow the
---`WinClosed` and `BufWinLeave` events the close raises (the autocmd is not
---`nested`). Deferring keeps those handlers in the quickfix window they were
---called for, and lets the close behave as any other window close.
---@param winid integer Window `:copen` or `:lopen` opened.
---@param is_loclist boolean
---@param owner integer? Window the location list belongs to.
local function _replace(winid, is_loclist, owner)
    if not vim.api.nvim_win_is_valid(winid) then return end
    if vim.bo[vim.api.nvim_win_get_buf(winid)].buftype ~= "quickfix" then return end

    local info = vim.fn.getwininfo(winid)[1]
    if not info then return end
    if is_loclist then
        -- The options may have been turned off between the event and this call.
        if info.loclist ~= 1 or not config.replace_lopen then return end
    else
        if info.quickfix ~= 1 or info.loclist == 1 or not config.replace_copen then return end
    end

    if not pcall(vim.api.nvim_win_close, winid, true) then return end
    if is_loclist then
        require("picker").pick("loclist", nil, { winid = owner })
    else
        require("picker").pick("quickfix")
    end
end

---@param args table nvim_create_autocmd callback args
local function _redirect(args)
    if vim.bo[args.buf].buftype ~= "quickfix" then return end
    local winid = vim.api.nvim_get_current_win()
    local info = vim.fn.getwininfo(winid)[1]
    if not info then return end

    local is_loclist = info.loclist == 1
    if is_loclist and not config.replace_lopen then return end
    if not is_loclist and not config.replace_copen then return end

    if #vim.api.nvim_tabpage_list_wins(0) <= 1 then return end

    -- A location list belongs to the window `:lopen` ran in, not to the scratch
    -- window it opened, so remember the former before the latter is closed.
    local owner = nil
    if is_loclist then
        owner = vim.fn.getloclist(winid, { filewinid = 1 }).filewinid
        if owner == 0 then owner = nil end
    end

    vim.schedule(function() _replace(winid, is_loclist, owner) end)
end

---Turn the redirects on or off. Idempotent: calling it again with the values
---already in force changes nothing.
---@param cfg picker.Config
function M.apply(cfg)
    vim.api.nvim_create_augroup(_AUGROUP, { clear = true })
    if not cfg.replace_copen and not cfg.replace_lopen then return end

    vim.api.nvim_create_autocmd("BufWinEnter", {
        group    = _AUGROUP,
        callback = _redirect,
        desc     = "Open the list picker in place of the native quickfix or location-list window",
    })
end

return M
