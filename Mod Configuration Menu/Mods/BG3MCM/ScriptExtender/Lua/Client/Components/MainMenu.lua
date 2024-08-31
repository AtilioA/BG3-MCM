MainMenu = {}

function MainMenu.CreateMainMenu()
    local function CreateHelpTroubleshootingPopup()
        local helpTroubleshootingPopup = MCM_WINDOW:AddPopup("Help & Troubleshooting")

        -- Adding content sections
        helpTroubleshootingPopup:AddSeparatorText("Troubleshooting and Reporting")
        helpTroubleshootingPopup:AddText(
            "Script Extender's (SE) IMGUI implementation is still in development. If you're having issues:")
        helpTroubleshootingPopup:AddBulletText("Disable overlays (Nvidia/AMD/Discord, etc);")
        helpTroubleshootingPopup:AddBulletText("If crashing under Vulkan, test without IMGUI mods like MCM")
        helpTroubleshootingPopup:AddBulletText("Verify the problem persists with no other DLL mods")
        helpTroubleshootingPopup:AddBulletText("Ensure you're using the latest BG3 version and SE Release version")

        helpTroubleshootingPopup:AddSeparatorText("Reporting Issues")
        helpTroubleshootingPopup:AddBulletText(
            "Provide SE console logs - you can easily enable the SE console via BG3MM preferences")
        helpTroubleshootingPopup:AddBulletText("Include system specs (GPU, CPU, OS)")
        helpTroubleshootingPopup:AddBulletText("Describe behavior under DirectX 11 and Vulkan")
        helpTroubleshootingPopup:AddBulletText("Upload crash reports if prompted by the SE")

        helpTroubleshootingPopup:AddSeparatorText("Known Issues")
        local uiNotShowingBT = helpTroubleshootingPopup:AddBulletText(
            "UI not showing up: test both Vulkan and DirectX 11")
        uiNotShowingBT:SetColor("Text", Color.HEXToRGBA("#FF2323"))
        helpTroubleshootingPopup:AddBulletText("Keybindings: Unfocus MCM window before using keybinds")

        helpTroubleshootingPopup:AddSeparatorText("More Information")
        helpTroubleshootingPopup:AddText("For more details, visit the MCM page on Nexus.")

        return helpTroubleshootingPopup
    end

    local function CreateHelpUIPopup()
        local helpPopupUI = MCM_WINDOW:AddPopup("UI Help")
        helpPopupUI:AddSeparatorText("UI Help")
        helpPopupUI:AddText("With MCM, you can configure the settings of mods that use MCM.")
        helpPopupUI:AddText("To get started, click a mod from the list on the left.")
        helpPopupUI:AddSeparatorText("Navigating the settings")
        helpPopupUI:AddText("All settings are saved automatically as you make changes.")
        helpPopupUI:AddText("To reset a setting, click the reset button next to it.")
        helpPopupUI:AddText("You can control + click a slider to type in a specific value.")
        helpPopupUI:AddSeparator()
        helpPopupUI:AddText("MCM uses IMGUI, which is a library also used by ReShade and other mods.")
        helpPopupUI:AddText("For more information, visit the MCM page on Nexus.")
        return helpPopupUI
    end

    local function CreateAboutGeneralPopup()
        -- New About popups
        local aboutPopupGeneral = MCM_WINDOW:AddPopup("About MCM - General")
        aboutPopupGeneral:SetColor("PopupBg", Color.HEXToRGBA("#1E1E1E"))
        local MCMModInfo = Ext.Mod.GetMod(ModuleUUID).Info
        local modAuthor = MCMModInfo.Author
        local modVersion = table.concat(MCMModInfo.ModVersion, ".")
        aboutPopupGeneral:AddSeparatorText("Mod Configuration Menu " .. modVersion .. " by " .. modAuthor)
        -- local aboutPopupDescription = MCM_WINDOW:AddPopup("About MCM - Description")
        -- aboutPopupGeneral:AddSeparatorText("Description")
        aboutPopupGeneral:AddText(
            "MCM is a centralized configuration menu for Baldur's Gate 3 mods, allowing easy management of mod settings."
        )
        aboutPopupGeneral:AddText(
            "It is designed to be user-friendly and accessible, providing a consistent interface for mod configuration."
        )
        aboutPopupGeneral:AddText(
            "It was the culmination of months of work done by mostly a single developer.\nIf you find it useful, please consider endorsing it on Nexus Mods and dropping a donation.")
        return aboutPopupGeneral
    end

    local function CreateAboutLicensePopup()
        local aboutPopupLicense = MCM_WINDOW:AddPopup("About MCM - License")
        aboutPopupLicense:AddSeparatorText("License")
        aboutPopupLicense:AddText(VCString:Wrap(
            "BG3MCM's code is licensed under AGPLv3. For details, refer to the GitHub link in the mod description.", 100))
        aboutPopupLicense:AddText(VCString:Wrap(
            "BG3MCM has code adapted from Compatibility Framework and Volition Cabinet, both under the MIT License, as well as BG3SE, which is licensed under the MIT License with an additional Commons Clause. Copies of these licenses have been included in the relevant sections of this mod's code.",
            100))
        aboutPopupLicense:AddText(VCString:Wrap(
            "Mod authors and translators may enable donation points for any mods using this framework as a dependency, and may freely use examples provided to help build integration with this mod.",
            100))
        aboutPopupLicense:AddText(VCString:Wrap(
            "The licensing terms on Nexus complement these permissions. In cases of overlap, the stricter of the two licensing terms should apply.",
            100))
        aboutPopupLicense:AddSeparator()
        aboutPopupLicense:AddText(VCString:Wrap(
            "I extend my gratitude to Norbyte, Focus and the CL team for making their code available under such open and permissive licenses, enabling seamless collaboration across the modding community!",
            100))

        return aboutPopupLicense
    end

    local m = MCM_WINDOW:AddMainMenu()

    local helpUIPopup = CreateHelpUIPopup()
    local helpTroubleshootingPopup = CreateHelpTroubleshootingPopup()
    local aboutPopupGeneral = CreateAboutGeneralPopup()
    local aboutLicense = CreateAboutLicensePopup()

    local help = m:AddMenu(Ext.Loca.GetTranslatedString("hbdf03cb8dff04632b32aeafd69cbdc406ea3"))

    local helpUIItem = help:AddItem(Ext.Loca.GetTranslatedString("h45722336fcb04208a1b46356190835bb2d86"))
    helpUIItem.OnClick = function()
        helpUIPopup:Open()
    end

    local helpTroubleshootItem = help:AddItem(Ext.Loca.GetTranslatedString("h81625d4fad964786b5ab2eb1901e4496d771"))
    helpTroubleshootItem.OnClick = function()
        helpTroubleshootingPopup:Open()
    end

    local about = m:AddMenu(Ext.Loca.GetTranslatedString("ha303b737440345dd831870ef6b4ff7256601"))

    local aboutItemGeneral = about:AddItem(Ext.Loca.GetTranslatedString("h38c503feb8094c3aae3839b16ea3a74ff1ad"))
    aboutItemGeneral.OnClick = function()
        aboutPopupGeneral:Open()
    end

    local aboutItemLicense = about:AddItem(Ext.Loca.GetTranslatedString("h75ea4d095c1f46dda375abaf9d79cbb51cc7"))
    aboutItemLicense.OnClick = function()
        aboutLicense:Open()
    end
end
