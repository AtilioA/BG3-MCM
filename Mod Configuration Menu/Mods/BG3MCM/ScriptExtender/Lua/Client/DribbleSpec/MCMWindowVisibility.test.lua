D.describe("MCM window visibility", { tags = { "visibility", "client", "unit" } }, function()
    ---@param windows table[]
    ---@return IMGUIAPI
    local function createAPI(windows)
        return setmetatable({
            GetMCMWindows = function() return windows end,
        }, { __index = {
            HideMCMWindows = IMGUIAPI.HideMCMWindows,
            ToggleMCMWindowsVisibility = IMGUIAPI.ToggleMCMWindowsVisibility,
        } })
    end

    D.test("restores visible windows and leaves hidden windows hidden", function()
        local main = { Visible = true, Open = true }
        local detached = { Visible = true, Open = true }
        local closed = { Visible = false, Open = false }
        local api = createAPI({ main, detached, closed })

        api:ToggleMCMWindowsVisibility()
        D.expect(main.Visible).toBe(false)
        D.expect(detached.Visible).toBe(false)
        D.expect(main.Open).toBe(true)
        D.expect(detached.Open).toBe(true)

        api:ToggleMCMWindowsVisibility()
        D.expect(main.Visible).toBe(true)
        D.expect(detached.Visible).toBe(true)
        D.expect(closed.Visible).toBe(false)
        D.expect(closed.Open).toBe(false)
    end)

    D.test("keeps windows hidden across repeated updates", function()
        local window = { Visible = true, Open = true }
        local api = createAPI({ window })

        api:ToggleMCMWindowsVisibility()
        api:HideMCMWindows()
        api:HideMCMWindows()
        D.expect(window.Visible).toBe(false)
        api:ToggleMCMWindowsVisibility()
        D.expect(window.Visible).toBe(true)
    end)

    D.test("hides and restores new windows and windows opened while hidden", function()
        local window = { Visible = false, Open = false }
        local windows = { window }
        local api = createAPI(windows)
        api:ToggleMCMWindowsVisibility()

        window.Visible = true
        window.Open = true
        local notification = { Visible = true, Open = true }
        table.insert(windows, notification)
        api:HideMCMWindows()
        D.expect(window.Visible).toBe(false)
        D.expect(notification.Visible).toBe(false)

        api:ToggleMCMWindowsVisibility()
        D.expect(window.Visible).toBe(true)
        D.expect(notification.Visible).toBe(true)
    end)

    D.test("does not access destroyed windows or reopen closed windows", function()
        local closed = { Visible = true, Open = true }
        local destroyed = { Visible = true, Open = true }
        local windows = { closed, destroyed }
        local api = createAPI(windows)
        api:ToggleMCMWindowsVisibility()

        closed.Open = false
        table.remove(windows, 2)
        destroyed.Visible = nil
        setmetatable(destroyed, { __index = function() error("Destroyed window accessed") end })
        api:HideMCMWindows()
        api:ToggleMCMWindowsVisibility()
        D.expect(closed.Open).toBe(false)
    end)

    D.test("can toggle before any MCM window exists", function()
        local api = createAPI({})
        api:ToggleMCMWindowsVisibility()
        api:ToggleMCMWindowsVisibility()
    end)
end)
