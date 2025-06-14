--- Provides localization handle lookups for native keybinding categories and event names.
--- This module maps keybinding identifiers to their display strings or localization handles.
---@class NativeKeybindingsTranslator
NativeKeybindingsTranslator = {}

-- Internal mapping of category names to their display strings
local _categoryStrings = {
  [""] = "h86fe2b0403a84fb7908f6bdf3ee17dd21e7f",
  ["CameraControls"] = "hbf47285d75054db8961a2bbd76e650fcd991",
  ["PhotoModeControls"] = "h726ccf29105d41538780a0a1b61bf3cab5f0",
  ["UI"] = "hd0c6191488c948b99d81f0cd66fc1ccb6a26",
  ["General"] = "h11c49d334a6d429eb1fa26da1379390a5333"
}

-- Internal mapping of event names to their display strings
local _eventStrings = {
  -- Camera Controls
  ["CameraForward"] = "h2d7144c5b0454e149411e2542ab303ae933b",
  ["CameraBackward"] = "h39a720e76b4141949a505be4a602a75d54ea",
  ["CameraLeft"] = "h7e26b3c3fa6a4606be5ba33fd622eb837e70",
  ["CameraRight"] = "h24831ad9f6ef40a5a98377fa56ee766d8f26",
  ["CameraZoomIn"] = "h5675f4200f7f46a2a2af47c66fa9ccac2221",
  ["CameraZoomOut"] = "hca0f71f6093a4bf695237cae5bd5a1badg51",
  ["CameraRotateLeft"] = "h1ce8fbd46d3a4f46acba57ed0a734bfa2ab5",
  ["CameraRotateRight"] = "h5563361ff2b744848871cdbaf12539c16c5b",
  ["CameraToggleMouseRotate"] = "h1174c660801b4143acde0a6f1dfc2a6ed5g8",

  -- Character Controls
  ["CharacterMoveForward"] = "h74811b458d7c4508a32237dc7e3efa173789",
  ["CharacterMoveBackward"] = "h5dfb2c27117d4b779116875a427ff373c18f",
  ["CharacterMoveLeft"] = "h7b47f1295b6d48d491e5bce102d5637f11cf",
  ["CharacterMoveRight"] = "h867a112c3e6e4ae2bbc52dd477dbf4e3b95e",
  ["Jump"] = "hb12f6c48442548e1b9e387a14d9a20aaee2c",
  ["ToggleSneak"] = "h7025fc893be6495088864712e05d0adaa889",
  ["Interact"] = "hdb227dc7309b42b885a9b133058c47aa5663",
  ["Shove"] = "h024c99f044774880a6a1a90dc1f1bcbfb56c",
  ["Throw"] = "h0956d399e7d54f3c9e52482048530abcf06d",

  -- UI Controls
  ["ToggleInventory"] = "h166a50bf762d4cd7a1d827184d336bb264df",
  ["ToggleCharacterOverview"] = "hab00d79972f3481784c6c31b1d5779f0c742",
  ["ToggleJournal"] = "h10c8d7eba5144bc4ac9ca09ff20f29e283af",
  ["ToggleMap"] = "h8745d6a103924a2fa748042b1c7b95734g00",
  ["ToggleSpells"] = "h70085eab331a4597bba1bfdcf6de0b5b8g23",
  ["ToggleCombatMode"] = "hd0e73646b7c14325ac1d7a7e2ad65f3c9ggd",
  ["ToggleWeaponSet"] = "ha67fb4a3797740c6b74aa406c9364064dd69",
  ["ToggleInGameMenu"] = "h9e7d63a517984acc84b5e64187cce82672d5",

  -- Common UI Actions
  ["UIAccept"] = "hf5e39ec5e1914d2a8f6a9ee6d6e888ed968e",
  ["UICancel"] = "h683a30d71c35413086cbd53bfd4f4e8da827",
  ["UILeft"] = "h579cabee5479438ab94dd3b8b47c66b70789",
  ["UIRight"] = "had916ada428d43119b088e53521f3beb99b3",
  ["UIUp"] = "h3ef3ea845c2e4902b8c4633a2c63209059g3",
  ["UIDown"] = "h85d3fde3585b4127b2ccfe271399b3a7a5ea",
  ["UITabNext"] = "h44a74f242dc842828ae26f5e91408b423def",
  ["UITabPrev"] = "h79de9dffb4604234a93e77eef26696835f1g"
}

--- Gets the display string for a category name.
---@param categoryName string The category name to look up
---@return string The display string for the category, or a default string if not found
function NativeKeybindingsTranslator.GetCategoryString(categoryName)
  if not categoryName then return _categoryStrings[""] end
  return _categoryStrings[categoryName] or _categoryStrings[""]
end

--- Gets the display string for an event name.
---@param eventName string The event name to look up
---@return string The display string for the event, or the original name if not found
function NativeKeybindingsTranslator.GetEventString(eventName)
  if not eventName then return "" end
  local str = _eventStrings[eventName]

  if not str then
    str = eventName:gsub("([A-Z])", " %1"):gsub("^%s+", "")
    _eventStrings[eventName] = str
  end

  local locString = Ext.Loca.GetTranslatedString(str)
  if locString and locString ~= "" then return locString end

  return str
end

return NativeKeybindingsTranslator
