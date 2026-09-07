---@diagnostic disable: undefined-global
-- Unit tests for `picker.create_cmd_alias`: the alias must be an `:Picker` in
-- every way that matters -- same arguments as typed, same completion, same
-- refusal to take a name already in use -- without `picker.cmdline` loading
-- until the alias is actually used.

local picker = require("picker")

-- Every case registers its own name, so the file is order-independent.
local n = 0

---Register a fresh alias and return its name.
---@return string
local function alias()
    n = n + 1
    local name = ("PickAlias%d"):format(n)
    assert.is_true(picker.create_cmd_alias(name))
    return name
end

---Run `fn` with `vim.notify` captured, restoring it afterwards.
---@param fn fun()
---@return string[]
local function notified(fn)
    local notes = {}
    local real = vim.notify
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg) notes[#notes + 1] = tostring(msg) end
    local ok, err = pcall(fn)
    vim.notify = real
    if not ok then error(err) end
    return notes
end

---Run `fn` with the module `name` replaced by `stub`, restoring it afterwards.
---@param name string
---@param stub table
---@param fn fun()
local function stubbed(name, stub, fn)
    local real = package.loaded[name]
    package.loaded[name] = stub
    local ok, err = pcall(fn)
    package.loaded[name] = real
    if not ok then error(err) end
end

describe("create_cmd_alias", function()
    it("registers the plugin's own argument shape", function()
        local name = alias()
        local cmd = vim.api.nvim_get_commands({})[name]
        assert.are.equal("*", cmd.nargs)
        assert.is_nil(cmd.range)
        assert.is_truthy(cmd.definition:find("alias for :Picker", 1, true))
    end)

    it("forwards the line as typed, escapes intact", function()
        local name = alias()
        local cap = {}
        stubbed("picker.cmdline", { run = function(o) cap = o end }, function()
            vim.cmd(name .. [[ files dir=my\ src]])
        end)
        assert.are.equal("files dir=my\\ src", cap.args)
        assert.are.same({ "files", "dir=my src" }, cap.fargs)
    end)

    it("delegates completion with the alias's own line", function()
        local name = alias()
        local got
        stubbed("picker.cmdline", {
            complete = function(a, l, c) got = { a, l, c }; return { "stub" } end,
        }, function()
            local line = name .. " files "
            assert.are.same({ "stub" }, vim.fn.getcompletion(line, "cmdline"))
            assert.are.same({ "", line, #line }, got)
        end)
    end)

    it("loads nothing when it registers", function()
        local real = package.loaded["picker.cmdline"]
        package.loaded["picker.cmdline"] = nil
        alias()
        local loaded = package.loaded["picker.cmdline"] ~= nil
        package.loaded["picker.cmdline"] = real
        assert.is_false(loaded)
    end)

    it("leaves a name that is already taken alone", function()
        local name = alias()
        local notes = notified(function()
            assert.is_false(picker.create_cmd_alias(name))
        end)
        assert.are.same(
            { ("[picker] :%s is already taken, so no alias was created"):format(name) }, notes)
    end)

    it("leaves the command's own name alone", function()
        notified(function()
            assert.is_false(picker.create_cmd_alias("Picker"))
        end)
    end)

    it("refuses a name that cannot be a user command", function()
        assert.has_error(function() picker.create_cmd_alias("pick") end)
        assert.has_error(function() picker.create_cmd_alias(nil) end)
    end)
end)
