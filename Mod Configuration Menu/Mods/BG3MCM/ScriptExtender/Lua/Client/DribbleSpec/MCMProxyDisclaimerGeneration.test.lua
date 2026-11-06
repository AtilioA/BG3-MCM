-- Fake views pin the shipped request behavior; they do not prove engine lifetime or Menu/Running order.
D.describe("MCMProxy tab insertion readiness", { tags = { "mcm_proxy_disclaimer", "client", "unit" } }, function()
    local ReplaySubject = Ext.Require("Lib/reactivex/subjects/replaysubject.lua")
    local MOD_UUID = "00000000-0000-0000-0000-00000000E025"
    local DISCLAIMER_HANDLE = "h99e6c7f6eb9c43238ca27a89bb45b9690607"

    local savedDualPane, savedUIReady

    D.beforeEach(function()
        savedDualPane = DualPane
        savedUIReady = MCMClientState.UIReady
        MCMClientState.UIReady = ReplaySubject.Create(1)
    end)

    D.afterEach(function()
        DualPane = savedDualPane
        MCMClientState.UIReady = savedUIReady
    end)

    ---@param name string
    ---@return table view
    local function FakeView(name)
        local view = { name = name, inserts = {}, disclaimers = {}, disclaimerCalls = {}, failures = 0 }

        function view:InsertModTab(...)
            if self.failures > 0 then
                self.failures = self.failures - 1
                error("transient insert failure", 0)
            end
            table.insert(self.inserts, { ... })
            if self.onInsert then self.onInsert(...) end
        end

        function view:CreateTabWithDisclaimer(...)
            table.insert(self.disclaimerCalls, { ... })
            if self.failures > 0 then
                self.failures = self.failures - 1
                error("transient disclaimer failure", 0)
            end
            local element = { Label = name .. " disclaimer" }
            table.insert(self.disclaimers, element)
            return { name = name .. " tab" }, element
        end

        return view
    end

    --- Create a request whose scheduled work runs when the test enters a game state
    ---@param ctx table
    ---@param skipDisclaimer? boolean
    ---@param tabId? string
    ---@return fun(gameState: string) enter
    ---@return function callback
    ---@return function handle
    ---@return function[] queued
    local function BeginRequest(ctx, skipDisclaimer, tabId)
        local queued = {}
        ctx.stub(VCTimer, "OnTicks", function(_, _, fn) table.insert(queued, fn) end)
        local callback = function() end
        local handle = MCMProxy:CreateTabInsertionHandler(MOD_UUID, "Fixture tab", callback, skipDisclaimer, tabId)
        return function(gameState)
            handle(gameState)
            local fn = table.remove(queued, 1)
            if fn then fn() end
        end, callback, handle, queued
    end

    ---@param view table
    local function BuildView(view)
        DualPane = view
        MCMClientState.UIReady:OnNext(true)
    end

    ---@return table seen
    local function SubscribeLaterObserver()
        local seen = { count = 0 }
        MCMClientState.UIReady:Subscribe(function() seen.count = seen.count + 1 end)
        return seen
    end

    D.test("waits two ticks and then for readiness before creating the disclaimer", function(ctx)
        local view = FakeView("A")
        DualPane = view
        local scheduled = {}
        ctx.stub(VCTimer, "OnTicks", function(_, ticks, fn) table.insert(scheduled, { ticks = ticks, fn = fn }) end)
        local handle = MCMProxy:CreateTabInsertionHandler(MOD_UUID, "Fixture tab", function() end, nil, "TAB_ID")

        handle("Menu")
        D.expect(scheduled[1].ticks).toBe(2)
        D.expect(#view.disclaimerCalls).toBe(0)

        scheduled[1].fn()
        D.expect(#view.disclaimerCalls).toBe(0)

        MCMClientState.UIReady:OnNext(false)
        D.expect(#view.disclaimerCalls).toBe(0)

        MCMClientState.UIReady:OnNext(true)
        D.expect(view.disclaimerCalls[1]).toEqual({ MOD_UUID, "Fixture tab", DISCLAIMER_HANDLE, "TAB_ID" })
    end)

    D.test("keeps one disclaimer across emissions, rebuilt views and repeated Menu states", function(ctx)
        local first, second = FakeView("first"), FakeView("second")
        local enter = BeginRequest(ctx)

        enter("Menu")
        BuildView(first)
        MCMClientState.UIReady:OnNext(true)
        BuildView(second)
        enter("Menu")

        D.expect(#first.disclaimerCalls).toBe(1)
        D.expect(#second.disclaimerCalls).toBe(0)
        enter("Running")
        D.expect(first.disclaimers[1].Label).toBe("")
        D.expect(#second.inserts).toBe(1)
    end)

    D.test("allows a reentrant readiness emission during insertion", function(ctx)
        local view = FakeView("A")
        local reentered = false
        view.onInsert = function()
            if not reentered then
                reentered = true
                MCMClientState.UIReady:OnNext(true)
            end
        end
        local enter = BeginRequest(ctx)
        enter("Running")
        BuildView(view)
        D.expect(#view.inserts).toBe(2)
    end)

    D.test("clears the disclaimer before inserting with the request arguments", function(ctx)
        local view = FakeView("A")
        local labelAtInsert
        view.onInsert = function() labelAtInsert = view.disclaimers[1].Label end
        local enter, callback = BeginRequest(ctx, nil, "TAB_ID")

        enter("Menu")
        BuildView(view)
        enter("Running")

        D.expect(labelAtInsert).toBe("")
        D.expect(view.inserts).toEqual({ { MOD_UUID, "Fixture tab", callback, nil, "TAB_ID" } })
    end)

    D.test("still inserts when the disclaimer handle is dead", function(ctx)
        local view = FakeView("A")
        local attempts = 0
        function view:CreateTabWithDisclaimer()
            return {}, setmetatable({}, {
                __newindex = function()
                    attempts = attempts + 1
                    error("IMGUI object no longer exists")
                end,
            })
        end
        local enter = BeginRequest(ctx)

        enter("Menu")
        BuildView(view)
        enter("Running")

        D.expect(attempts).toBe(1)
        D.expect(#view.inserts).toBe(1)
    end)

    D.test("skipDisclaimer keeps both the Menu and Running observers inserting", function(ctx)
        local view = FakeView("A")
        local enter, callback = BeginRequest(ctx, true)

        enter("Menu")
        BuildView(view)
        D.expect(view.inserts[1]).toEqual({ MOD_UUID, "Fixture tab", callback, true })
        D.expect(#view.disclaimerCalls).toBe(0)

        enter("Running")
        D.expect(#view.inserts).toBe(2)

        MCMClientState.UIReady:OnNext(true)
        D.expect(#view.inserts).toBe(4)
    end)

    D.test("stops scheduling after insertion and keeps the observer live", function(ctx)
        local first, second = FakeView("first"), FakeView("second")
        local enter, _, _, queued = BeginRequest(ctx)

        enter("Running")
        BuildView(first)
        D.expect(#first.inserts).toBe(1)

        enter("Menu")
        D.expect(#queued).toBe(0)

        BuildView(second)
        D.expect(#second.inserts).toBe(1)
        D.expect(#second.disclaimers).toBe(0)
    end)

    D.test("runs a tick that was queued before insertion", function(ctx)
        local view = FakeView("A")
        BuildView(view)
        local _, _, handle, queued = BeginRequest(ctx)

        handle("Running")
        handle("Running")
        queued[1]()
        queued[2]()

        D.expect(#view.inserts).toBe(2)
    end)

    D.test("retries the disclaimer on the next emission after a transient replay failure", function(ctx)
        local view = FakeView("A")
        view.failures = 1
        BuildView(view)
        local enter = BeginRequest(ctx)

        -- Expects the fake view's transient replay error.
        local replayed, replayError = pcall(enter, "Menu")
        D.expect(replayed).toBe(false)
        D.expect(replayError).toBe("transient disclaimer failure")
        D.expect(#view.disclaimers).toBe(0)

        local later = SubscribeLaterObserver()
        D.expect(later.count).toBe(1)

        MCMClientState.UIReady:OnNext(true)
        D.expect(#view.disclaimerCalls).toBe(2)
        D.expect(#view.disclaimers).toBe(1)
        D.expect(later.count).toBe(2)

        enter("Running")
        D.expect(view.disclaimers[1].Label).toBe("")
        D.expect(#view.inserts).toBe(1)
    end)

    D.test("retries insertion on the next emission after a transient replay failure", function(ctx)
        local view = FakeView("A")
        view.failures = 1
        BuildView(view)
        local enter, _, handle, queued = BeginRequest(ctx)

        -- Expects the fake view's transient replay error.
        local replayed, replayError = pcall(enter, "Running")
        D.expect(replayed).toBe(false)
        D.expect(replayError).toBe("transient insert failure")
        D.expect(#view.inserts).toBe(0)

        handle("Loading")
        D.expect(#queued).toBe(1)
        table.remove(queued, 1)

        local later = SubscribeLaterObserver()
        MCMClientState.UIReady:OnNext(true)
        D.expect(#view.inserts).toBe(1)
        D.expect(later.count).toBe(2)

        handle("Menu")
        D.expect(#queued).toBe(0)
    end)

    D.test("retries on the next emission after a transient emission failure", function(ctx)
        local view = FakeView("A")
        local enter = BeginRequest(ctx)
        enter("Running")
        local later = SubscribeLaterObserver()
        DualPane = view
        view.failures = 1

        -- Expects the fake view's transient emission error.
        local emitted, emissionError = pcall(function() MCMClientState.UIReady:OnNext(true) end)
        D.expect(emitted).toBe(false)
        D.expect(emissionError).toBe("transient insert failure")
        D.expect(later.count).toBe(0)

        MCMClientState.UIReady:OnNext(true)
        D.expect(#view.inserts).toBe(1)
        D.expect(later.count).toBe(1)
    end)
end)
