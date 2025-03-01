MainMenu = {}

function MainMenu.CreateMainMenu()
    local function CreateHelpTroubleshootingPopup()
        local helpTroubleshootingPopup = MCM_WINDOW:AddPopup(Ext.Loca.GetTranslatedString(
            "hbdd48c8cba3e4c31931f1647cb5d73c813ef"))

        -- Adding content sections
        helpTroubleshootingPopup:AddSeparatorText(Ext.Loca.GetTranslatedString("h361dd694cca74b30a87f02d035e35dcac0d4"))
        local text1 = helpTroubleshootingPopup:AddText(
            Ext.Loca.GetTranslatedString(
                "hafec095716ec4208b2319d24b3c230d969d4"))
        text1.TextWrapPos = 0
        helpTroubleshootingPopup:AddBulletText(Ext.Loca.GetTranslatedString(
            "h11f519e028834967a79753cfe1e6cae28726"))
        helpTroubleshootingPopup:AddBulletText(Ext.Loca.GetTranslatedString(
            "h264b744397944591bbfbcd2c69f57d2b7150"))
        helpTroubleshootingPopup:AddBulletText(Ext.Loca.GetTranslatedString(
            "h28faf9b0ffb34b109f4ad73eaed97833896g"))
        helpTroubleshootingPopup:AddBulletText(Ext.Loca.GetTranslatedString(
            "h48cad338a0ab4c06bb9060d24a8a5e52e52e"))

        helpTroubleshootingPopup:AddSeparatorText(Ext.Loca.GetTranslatedString("h52b099d222d14e21a68cbc088314712856dc"))
        helpTroubleshootingPopup:AddBulletText(
            Ext.Loca.GetTranslatedString(
                "h2021eb6360bd4cce955f32816edc5b06abdg"))
        helpTroubleshootingPopup:AddBulletText(Ext.Loca.GetTranslatedString("h4d23bb6e90d2429aa85dea0d7bd5774a79ed"))
        helpTroubleshootingPopup:AddBulletText(Ext.Loca.GetTranslatedString(
            "ha1dd54cb1e754f1099bbf9889210d19c6904"))
        helpTroubleshootingPopup:AddBulletText(Ext.Loca.GetTranslatedString("hc417ce5922854d5dae5c51d7a3dae9b46f19"))

        helpTroubleshootingPopup:AddSeparatorText(Ext.Loca.GetTranslatedString("hcb35f546c52546949cbd5bda88fe2af91656"))
        local uiNotShowingBT = helpTroubleshootingPopup:AddBulletText(
            Ext.Loca.GetTranslatedString("h90617d43407c4d5d99fe26d08f47934abg89"))
        uiNotShowingBT:SetColor("Text", Color.HEXToRGBA("#FF2323"))

        helpTroubleshootingPopup:AddSeparatorText(Ext.Loca.GetTranslatedString("h1fe5d3876dd04389b53f1c4d808d2d02gfce"))
        local text2 = helpTroubleshootingPopup:AddText(Ext.Loca.GetTranslatedString(
            "h449f8e9c50fe497e8584a92dc227759a1d5d"))
        text2.TextWrapPos = 0

        return helpTroubleshootingPopup
    end

    local function CreateHelpUIPopup()
        local helpPopupUI = MCM_WINDOW:AddPopup(Ext.Loca.GetTranslatedString("ha41e66cbd942447c808e6bd19f0ff635f69e"))
        helpPopupUI:AddSeparatorText(Ext.Loca.GetTranslatedString("h504a5f8e7f544190b496bcde61c78dcb7ba6"))
        local text1 = helpPopupUI:AddText(Ext.Loca.GetTranslatedString(
            "hfadac6e330134b9ba8e5e2f1a16cf77cd3bg"))
        text1.TextWrapPos = 0
        local text2 = helpPopupUI:AddText(Ext.Loca.GetTranslatedString(
            "h54470141a99c47ba95e92f57da1100de5467"))
        text2.TextWrapPos = 0
        helpPopupUI:AddSeparatorText(Ext.Loca.GetTranslatedString("h126fa009e82d48508463fd049554b08bb8a0"))
        local text3 = helpPopupUI:AddText(Ext.Loca.GetTranslatedString(
            "hc9997429f80b488a91c26118fd7662a2ae73"))
        text3.TextWrapPos = 0
        local text4 = helpPopupUI:AddText(Ext.Loca.GetTranslatedString(
            "h28b119e5d1534fa581ad2c7011f8ce7f7577"))
        text4.TextWrapPos = 0
        local text5 = helpPopupUI:AddText(Ext.Loca.GetTranslatedString(
            "had9d11b7951441e3826b571a2a445cc14286"))
        text5.TextWrapPos = 0
        helpPopupUI:AddSeparator()
        local text6 = helpPopupUI:AddText(Ext.Loca.GetTranslatedString(
            "he3146562f01e4896b2fbd158587a69d6b33b"))
        text6.TextWrapPos = 0
        local text7 = helpPopupUI:AddText(Ext.Loca.GetTranslatedString(
            "he67fc60b9866404a83b49e151d88bf7dg39d"))
        text7.TextWrapPos = 0
        return helpPopupUI
    end

    local function CreateAboutGeneralPopup()
        -- New About popups
        local aboutPopupGeneral = MCM_WINDOW:AddPopup(Ext.Loca.GetTranslatedString(
            "hf2c6ba6f913344bf8ac81e2a4915213f702g"))
        aboutPopupGeneral:SetColor("PopupBg", Color.HEXToRGBA("#1E1E1E"))
        local MCMModInfo = Ext.Mod.GetMod(ModuleUUID).Info
        local modAuthor = MCMModInfo.Author
        local modVersion = table.concat(MCMModInfo.ModVersion, ".")
        aboutPopupGeneral:AddSeparatorText(VCString:InterpolateLocalizedMessage("h4a0ed3db05bb46c59094f7d5be8e90fa09d2",
        modVersion, modAuthor))
        -- local aboutPopupDescription = MCM_WINDOW:AddPopup("About MCM - Description")
        -- aboutPopupGeneral:AddSeparatorText("Description")
        aboutPopupGeneral:AddText(
            Ext.Loca.GetTranslatedString(
                "h03d35de7f7cf49fcb748f08dd7bd46fb5474")
        )
        aboutPopupGeneral:AddText(
            Ext.Loca.GetTranslatedString(
                "hbefc18dccd3646c3bee89e1c8a773eee8c44")
        )
        aboutPopupGeneral:AddText(
            Ext.Loca.GetTranslatedString(
                "ha3e6f6909b9744fcb28a1be741580718eebc"))
        return aboutPopupGeneral
    end

    local function CreateAboutLicensePopup()
        local aboutPopupLicense = MCM_WINDOW:AddPopup(Ext.Loca.GetTranslatedString(
            "h5bce8e943b4f4effa9f3b5f44caf244360ea"))
        aboutPopupLicense:AddSeparatorText(Ext.Loca.GetTranslatedString("h2c396610bbc24069bf3ee724d868fad5g2e7"))
        aboutPopupLicense:AddText(VCString:Wrap(
            Ext.Loca.GetTranslatedString(
                "h63f26391dd0c4953b167c927ce04240057c7"),
            100))
        aboutPopupLicense:AddText(VCString:Wrap(
            Ext.Loca.GetTranslatedString(
                "h9f85429a1ac84568b1c53940d5f28bc1a2e6"),
            100))
        aboutPopupLicense:AddText(VCString:Wrap(
            Ext.Loca.GetTranslatedString(
                "hd006c103dba44c48bb3826b5dbbe3f6133b1"),
            100))
        aboutPopupLicense:AddText(VCString:Wrap(
            Ext.Loca.GetTranslatedString(
                "h445fe7fd555e480f9090a0203b1d0a0811g7"),
            100))
        aboutPopupLicense:AddSeparator()
        aboutPopupLicense:AddText(VCString:Wrap(
            Ext.Loca.GetTranslatedString(
                "h4fbe91cade4c4f2f904e55bf12b3ec22egfc"),
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
