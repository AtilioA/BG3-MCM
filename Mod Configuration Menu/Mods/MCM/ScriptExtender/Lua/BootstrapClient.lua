-- -- -- Ext.Require("Shared/_Init.lua")
-- -- -- Ext.Require("Client/_Init.lua")

-- Ext.RegisterNetListener("MCM", function(_, payload)
--     _D("NetMessage:")
--     _D(Ext.Json.Parse(payload))
-- end)

-- PartyTable = {}


-- textbox = w:AddInputText("New name:", "simosas")

-- button = w:AddButton("Change name")

-- combo = w:AddCombo("Select party member")

-- cycleindex = w:AddButton("Change selected member")

-- currentindex = 0

-- cycleindex.OnClick = function()
--     if (currentindex > #combo.Options) then
--         combo.SelectedIndex = 0
--         currentindex = 0
--     else
--         combo.SelectedIndex = currentindex
--         currentindex = currentindex + 1
--     end
-- end


-- updatebutton = w:AddButton("Update party table")

-- button.OnClick = function()
--     CharTable = {}
--     CharTable["NewName"] = textbox.Text
--     CharTable["UUID"] = PartyTable[combo.SelectedIndex + 1]
--     _D(CharTable)
--     Ext.Net.PostMessageToServer("ChangeDaName", Ext.Json.Stringify(CharTable))
-- end

-- updatebutton.OnClick = function()
--     Ext.Net.PostMessageToServer("GiveTableUpdate", "")
-- end

-- Ext.Events.NetMessage:Subscribe(function(e)
--     if (e.Channel == "PopulateUI") then
--         combo.Options = {}
--         print("UI POPULATION")
--         StupidJson = Ext.Json.Parse(e.Payload)
--         PartyTable = StupidJson
--         for i = 1, #StupidJson, 1 do
--             combo.Options[i] = Ext.Loca.GetTranslatedString(Ext.Entity.Get(StupidJson[i][1]).DisplayName.NameKey.Handle
--             .Handle)
--         end
--     end
-- end)

-- Ext.Require("Shared/_Init.lua")
-- Ext.Require("Client/_Init.lua")

IMGUI_WINDOW = Ext.IMGUI.NewWindow("Mod Configuration Menu")
IMGUI_WINDOW.Closeable = true
IMGUI_WINDOW.Visible = true
ClientGlobals = {
    MOD_SETTINGS = {}
}

Ext.RegisterNetListener("MCM_Settings_To_Client", function(_, payload)
    ClientGlobals.MOD_SETTINGS = Ext.Json.Parse(payload)
    CreateModMenu()
end)

function CreateModMenu()
    IMGUI_WINDOW:AddInputText("Shrimple,", "Yet elusive :norb:")
end

-- Ext.RegisterNetListener(CHANNELS["party"], function(_, payload)
--     -- ClientGlobals["PARTY"] = JSON.Parse(payload)
--     -- BasicPrint("Got Party info from server : ")
--     -- BasicPrint(ClientGlobals["PARTY"])
--     if not TMOG_MENU_GROUP then
--         CreateTmogMenu(TMOG_TAB)
--         ClientGlobals["FLAGS"]["PartyInitDone"] = true
--     end
-- end)

-- Ext.RegisterNetListener("MCM_Settings_To_Client", function(_, payload)

Ext.RegisterNetListener("MCM_SetConfigValue", function(_, payload)
    local data = Ext.Json.Parse(payload)
    settings[data.modGUID].settings[data.settingName] = data.value
end)
