D.describe("MCM window visibility", { tags = { "visibility", "client", "unit" } }, function()
    ---@param windows table[]
    ---@return IMGUIAPI
    local function createAPI(windows)
        return setmetatable({
            GetMCMWindows = function() return windows end,
        }, { __index = {
            HideMCMWindows = IMGUIAPI.HideMCMWindows,
            ToggleMCMWindowsVisibility = IMGUIAPI.ToggleMCMWindowsVisibility,
            OpenMCMWindow = IMGUIAPI.OpenMCMWindow,
            CloseMCMWindow = IMGUIAPI.CloseMCMWindow,
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

    local MOD_A = "00000000-0000-0000-0000-00000000A001"
    local MOD_B = "00000000-0000-0000-0000-00000000B002"
    local MODS = { { id = MOD_A, name = "Alpha" }, { id = MOD_B, name = "Beta" } }

    --- Recently used list with one new use after the session's ranks froze, on a stand-in main window
    ---@param ctx table
    ---@param visible boolean Whether the main window starts visible
    ---@return table session
    local function RankingSession(ctx, visible)
        local values = { ModListPreferences = { SortMode = "recent" } }
        local state = ModListState:New({
            RegisterVar = function() return true end,
            IsWritable = function() return true end,
            Get = function(var) return values[var] end,
            Set = function(var, value) values[var] = value; return true end,
        })
        state:Resolve(MODS)
        state.preferences:RecordOpen(MOD_B)
        local session = { state = state, rebuilds = 0, main = { Visible = visible, Open = visible } }
        local pane = setmetatable({ visibility = state, mods = {},
            RebuildModEntries = function() session.rebuilds = session.rebuilds + 1 end }, LeftPane)
        session.api = createAPI({ session.main })
        local previousWindow = MCM_WINDOW
        MCM_WINDOW = session.main
        ctx.sandbox:TrackRestore(function() MCM_WINDOW = previousWindow end)
        ctx.stub(DualPane.leftPane, "StartRankingSession", function() pane:StartRankingSession() end)
        ctx.stub(MCMClientState, "EnsureWindowIsWithinViewport", function() end)
        ctx.stub(MCMClientState, "EnsureWindowFocused", function() end)
        -- Stands in for the DualPaneController subscription; only a real close emits this channel.
        ctx.stub(ModEventManager, "Emit", function(_, channel)
            if channel == EventChannels.MCM_WINDOW_CLOSED then pane:StartRankingSession() end
        end)
        return session
    end

    local function firstEntry(session)
        return session.state:Resolve(MODS).main[1].id
    end

    D.test("hiding a visible main window refreshes ranks once, and revealing keeps them", function(ctx)
        local session = RankingSession(ctx, true)
        D.expect(firstEntry(session)).toBe(MOD_A)

        session.api:ToggleMCMWindowsVisibility()
        D.expect(session.rebuilds).toBe(1)
        D.expect(firstEntry(session)).toBe(MOD_B)

        session.state.preferences:RecordOpen(MOD_A)
        session.api:ToggleMCMWindowsVisibility()
        D.expect(session.main.Visible).toBe(true)
        D.expect(session.rebuilds).toBe(1)
        D.expect(firstEntry(session)).toBe(MOD_B)
    end)

    D.test("hiding while the main window is closed starts no ranking session", function(ctx)
        local session = RankingSession(ctx, false)
        session.api:ToggleMCMWindowsVisibility()
        D.expect(session.rebuilds).toBe(0)
        D.expect(firstEntry(session)).toBe(MOD_A)
    end)

    D.test("opening an already visible window keeps the frozen ranks", function(ctx)
        local session = RankingSession(ctx, true)
        session.api:OpenMCMWindow(true)
        D.expect(session.rebuilds).toBe(0)
        D.expect(firstEntry(session)).toBe(MOD_A)
    end)

    D.test("closing and reopening refreshes ranks at the close", function(ctx)
        local session = RankingSession(ctx, true)
        session.api:CloseMCMWindow(true)
        D.expect(session.rebuilds).toBe(1)
        session.api:OpenMCMWindow(true)
        D.expect(session.rebuilds).toBe(1)
        D.expect(firstEntry(session)).toBe(MOD_B)
    end)
end)
