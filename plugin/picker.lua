if vim.fn.has("nvim-0.10") ~= 1 then
    error("picker.nvim requires Neovim >= 0.10")
end

if vim.g.loaded_picker then return end
vim.g.loaded_picker = true

-- Nothing under `lua/picker/` is required here: the command and the highlight
-- groups are all that has to exist before the first pick, so they are written
-- out rather than pulled in. `picker.apply_highlights()` states the same groups
-- for the `colorschemes` source, which re-applies them after a scheme switch.
vim.api.nvim_set_hl(0, "PickerMatch", { default = true, link = "Visual" })
vim.api.nvim_set_hl(0, "PickerPath", { default = true, link = "@module" })
vim.api.nvim_set_hl(0, "PickerLspReference", { default = true, link = "Label" })
vim.api.nvim_set_hl(0, "PickerBufferIndicator", { default = true, link = "Special" })
vim.api.nvim_set_hl(0, "PickerFlagPill", { default = true, link = "Visual" })

vim.api.nvim_create_user_command("Picker", function(cmd_opts)
    require("picker.cmdline").run(cmd_opts)
end, {
    nargs    = "*",
    desc     = "Picker for files, grep etc...",
    complete = function(arg_lead, cmd_line, cursor_pos)
        return require("picker.cmdline").complete(arg_lead, cmd_line, cursor_pos)
    end,
})
