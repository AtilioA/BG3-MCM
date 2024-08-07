[size=3][b]Baldur's Gate 3 [color=#6d9eeb]Mod Configuration Menu[/color] ([color=#6d9eeb]MCM[/color]) provides an in-game menu through which mod users can configure mod settings.[/b][/size]
It is a central location for mod configuration and can be accessed via the ESC menu or pressing the [i]Insert[/i] key (by default).

Are you a mod author? Check the [url=https://wiki.bg3.community/Tutorials/Mod-Frameworks/mod-configuration-menu]documentation for integrating mods with the MCM[/url]; it's a simple process and there are a lot of features you definitely want to hear about!

[color=#6d9eeb][size=5][b]Features[/b][/size][/color]
[list]
[*][b]Configuration made easy[/b]: MCM provides a simple and intuitive way to change mods' settings. No need to manually edit JSON files - although still allowed, just like in the old days!
[*] [b]Instant setting saving and loading[/b]: Unlike the traditional way of handling settings, MCM-integrated mods update settings in real-time as they are changed, without requiring save reloads or SE commands;
[*][b]UI agnostic[/b]: MCM's core configuration code is designed to work independently of IMGUI. This means that even if IMGUI support were to be completely removed, MCM would still work. [b]Users who can't see the current UI will still be able to use MCM's under-the-hood benefits to manage their settings, and also edit them through JSON files[/b].
[*] [b]Save-safe[/b]: MCM does not write anything to your save files - all modifications are done in-memory and then saved to JSON files. MCM can also be safely uninstalled without affecting your save files at any time, provided any mods that use it are disabled or uninstalled as well;
[*] [b]Multiple profiles[/b]: MCM allows you to manage multiple configuration profiles, so you can have different settings for different playthroughs/characters;
[*] [b]Reduced user error[/b]: MCM performs several settings validations, reducing the risk of user error when configuring mods, even if manually editing JSON files;
[*] [b]Export and import settings[/b]: Mod settings are stored per-profile and per-mod JSON files under [font=Courier New]Script Extender\BG3MCM[/font], making it easy to create backups and restore settings.
[*] [b]Uncluttered UI[/b]: MCM consolidates all mod settings into one interface, reducing screen clutter.
[*] [b]Robust[/b]: MCM has dozens of automated tests to ensure it works as expected, without halting;
[*] [b]Localization support[/b]: MCM allows you to view settings in your preferred language, if translations are provided by mod authors/translators;
[/list]
[color=#6d9eeb][size=5][b]Installation[/b][/size][/color]
[b]Installation is essentially the same as any other pak mod[/b] and can be performed with new and existing saves:
[list=1]
[*]In [url=https://github.com/LaughingLeader/BG3ModManager]Baldur's Gate 3 Mod Manager[/url], (or use Vortex at your own discretion), install/enable the Script Extender (SE) by clicking on the 'Tools' tab at the top left of the program and selecting 'Download and Extract the Script Extender'. [b]Alternatively,[size=2][size=2] press CTRL+SHIFT+ALT+T while BG3MM's window is focused;[/size][/size][/b]
[*]Import this mod's .zip file into the Mod Manager, then drag the mod from the right panel of the Mod Manager to the left panel; make sure to [b]drag it to the top of your load order[/b], as it needs to be placed above any mods that rely on this framework;
[*]Save and export your load order. MCM will now automatically pick up and be available to any mods that may use it.
[/list]
You will see a button for MCM in the ESC menu in-game. It can also be opened with the INSERT key by default.[size=4][b]
[/b][/size][b]
UI support in SE has been significantly improved since launch, but you may still face some issues that are beyond my control.[/b] If you don't see the MCM window, you can try these things:
[list=1]
[*]restart your game ([color=#e06666][b]don't alt-tab before reaching the main menu[/b][/color]);
[*]disable overlays (Discord/AMD/NVIDIA/OBS/etc);
[*]switch to Vulkan.
[/list]
Older GPUs (from before ~2016) tend to have issues with the Script Extender's IMGUI implementation pre v18 (v18 has been released already), and I can't help with that. Even if you still have issues with it, MCM will continue working as a config/JSON manager even if the window does not appear.[line]
I have updated most of my mods to be integrated with MCM:
[list]
[*][size=2][size=2][size=2][url=https://www.nexusmods.com/baldursgate3/mods/9701]Mod Uninstaller[/url]﻿[/size][/size][/size]
[*][size=2][size=2][size=2][url=https://www.nexusmods.com/baldursgate3/mods/10795]Fix Stragglers[/url]﻿[/size][/size][/size]
[*][size=2][size=2][size=2][size=2][url=https://www.nexusmods.com/baldursgate3/mods/11172]Configurable Party Limit[/url]﻿[/size][/size][/size][/size]
[*][size=2][size=2][size=2][size=2][url=https://www.nexusmods.com/baldursgate3/mods/6995]Waypoint Inside Emerald Grove[/url][/size][/size][/size][/size]
[*][size=2][b][url=https://www.nexusmods.com/baldursgate3/mods/6313]Preemptively Label Containers[/url]﻿[/b] [/size]
[*][size=2][url=https://www.nexusmods.com/baldursgate3/mods/6086]Auto Send Food To Camp[/url][/size]
[*][size=2][url=https://www.nexusmods.com/baldursgate3/mods/5899]Smart Autosaving[/url][/size]
[*][size=2][url=https://www.nexusmods.com/baldursgate3/mods/10744]Short Rest Cooldown[/url][/size]
[*][size=2][url=https://www.nexusmods.com/baldursgate3/mods/6880]Auto Use Soap[/url]﻿[/size]
[*][size=2][url=https://www.nexusmods.com/baldursgate3/mods/6188]Auto Lockpicking[/url][/size]
[*][size=2][size=2][b][size=4][url=https://www.nexusmods.com/baldursgate3/mods/7035][size=4][size=2]Auto Send Read Books To Camp[/size][/size][/url]﻿[/size][/b][/size][/size]
[/list][size=2][size=2]As a demonstration, their MCM settings will also be localized in PT-BR 🇧🇷.[/size]

[size=2]Consider [b]politely asking[/b] authors of mods that use the Script Extender to integrate with MCM![/size]
[/size]Here's MCM (older 1.0 version) in action with Fararagi's [url=https://www.nexusmods.com/baldursgate3/mods/2861]Configurable Movement Speed[/url] (pretend you can read the menu in this heavily-compressed GIF):
[img]https://i.imgur.com/yDEouAG.gif[/img]﻿[line]
[size=4][b]Reports & requests[/b][/size]
It [i]works[/i] in multiplayer, but it is recommended to decide on one player to do all the changes, preferably the host.
Please report any other issues using the [b]Bugs[/b] tab.
Suggestions are welcome in the [b]Forum[/b] or [b]Posts[/b] tab.

[size=4][b]Files location[/b][/size]
Individual user settings can be located in the [font=Courier New]BG3MCM\Profiles\<PROFILE_NAME>\<MOD_NAME>\[/font] folder. If you're feeling adventurous, here's a spoiler with an [i]example[/i] of the full file structure:
[spoiler]You can find the root folder on Windows by pressing WIN+R and entering:[quote][code]explorer %LocalAppData%\Larian Studios\Baldur's Gate 3\Script Extender\BG3MCM[/code][/quote]BG3MCM/
│   mcm_params.json (Stores profile data, needed to be able to load profiles)
│   mod_configuration_menu_config.json (Manages a few MCM settings before MCM can load its own settings)
└───Profiles
    ├───Default
    │   ├───AutoSendFoodToCamp
    │   │       settings.json (Stores current values for mod Auto Send Food To Camp)
    │   ├───PreemptivelyLabelContainers
    │   │       settings.json
    │   └───WaypointInsideEmeraldGrove
    │           settings.json
    ├───Profile 1
    │   ├───AutoSendFoodToCamp
    │   │       settings.json
    │   └───WaypointInsideEmeraldGrove
    │           settings.json[/spoiler]
[b][size=4]Special thanks[/size][/b]
Similar to my experience with [url=https://www.nexusmods.com/baldursgate3/mods/8295]ISF[/url], I'd like to thank the foundational work of [url=https://www.nexusmods.com/baldursgate3/users/21094599]Focus[/url]﻿ and [url=https://www.nexusmods.com/baldursgate3/users/244952?tab=user+files]Nells[/url]﻿/[url=https://github.com/BG3-Community-Library-Team/]Community Library team[/url]. While applied to a lesser extent in this context, their insights throughout ISF have made this (initially) month-long endeavor a much less daunting task. I will be forever grateful for their open-source contributions to the Baldur's Gate 3 modding scene. Of course, none of this would be possible without the work put into Script Extender & LSLib by [url=https://github.com/Norbyte/]Norbyte[/url]﻿ and his responsiveness to feedback and troubleshooting. It was a pleasure working asynchronously with you, gentlemen 🎩👌.
Also, a shoutout to [url=https://www.nexusmods.com/baldursgate3/users/64167336?tab=user+files]Fallen[/url] for alpha testing this mod, to [url=https://next.nexusmods.com/profile/skiz/mods?gameId=3474]Skiz[/url] for being in the IMGUI trenches with me, to [url=https://next.nexusmods.com/profile/Aahz07/about-me?gameId=3474]Aahz[/url] for some help with the dreaded state management involving client-side UI and porting vanilla icons for usage inside IMGUI, to the [url=https://www.nexusmods.com/fallout4/mods/21497]F4MCM[/url] team for inspiration, to [url=https://next.nexusmods.com/profile/MattifusP/]MattifusP[/url]﻿ for the contributions on GitHub and to many others in the modding community that shared support!
[size=4][b]
Source Code
[/b][/size]The source code is available on [url=https://github.com/AtilioA/BG3-MCM/]GitHub[/url] or by unpacking the .pak file. Endorse on Nexus and give it a star on GitHub if you liked it!
[line]
[center][b][size=4][/size][/b][/center][center][b][size=4]My mods
[/size][/b][size=2][url=https://www.nexusmods.com/baldursgate3/mods/6995]Waypoint Inside Emerald Grove[/url] - adds an actual waypoint inside Emerald Grove
[size=2][url=https://www.nexusmods.com/baldursgate3/mods/10795]Fix Stragglers[/url]﻿ - automatically boosts/teleports companions who get stuck or fall behind[/size]
[url=https://www.nexusmods.com/baldursgate3/mods/11172]Configurable Party Limit[/url]﻿ - allows decreasing/increasing the party size with MCM
[url=https://www.nexusmods.com/baldursgate3/mods/7034]Reduce NPC Banter Repetitiveness[/url]﻿ - adds delays before [size=2]NPC banter[/size] repeats
[b][size=4][url=https://www.nexusmods.com/baldursgate3/mods/7035][size=4][size=2]Auto Send Read Books To Camp[/size][/size][/url]﻿[size=4][size=2] [/size][/size][/size][/b][size=4][size=4][size=2]- [size=2][size=2]automatically[/size][/size] [/size][/size][/size][size=2]sends read books to camp chest [/size]
[url=https://www.nexusmods.com/baldursgate3/mods/6880]Auto Use Soap[/url]﻿ - automatically uses soap after combat/entering camp[b]
[/b][b][url=https://www.nexusmods.com/baldursgate3/mods/6313]Preemptively Label Containers[/url]﻿[/b] - automatically tags nearby containers with 'Empty' or their item count[b]
[/b][url=https://www.nexusmods.com/baldursgate3/mods/5899]Smart Autosaving[/url] - creates conditional autosaves at set intervals
[url=https://www.nexusmods.com/baldursgate3/mods/10744]Short Rest Cooldown[/url]﻿ - enforces configurable cooldown after using short rest
[url=https://www.nexusmods.com/baldursgate3/mods/6086]Auto Send Food To Camp[/url] - sends food to camp chest automatically
[url=https://www.nexusmods.com/baldursgate3/mods/6188]Auto Lockpicking[/url] - initiates lockpicking automatically
[/size][size=1]
[/size][size=3][b]Tools/Resources[/b][/size][size=2]
[size=2][url=https://www.nexusmods.com/baldursgate3/mods/9701]Mod Uninstaller[/url]﻿ - allows uninstalling mods that add items/statuses[/size]
[size=2][url=https://www.nexusmods.com/baldursgate3/mods/9162]Mod Configuration Menu[/url]﻿ - [/size][/size]offers a graphical interface for easy management of mod settings[size=2]
[url=https://www.nexusmods.com/baldursgate3/mods/8295]AV Item Shipment Framework[/url]﻿ - allows authors to easily send items to player/camp chests
[url=https://www.nexusmods.com/baldursgate3/mods/7676]Volition Cabinet[/url]﻿ - library mod for my other mods
[/size][size=2][size=2]
[/size][url=https://ko-fi.com/volitio]   [img]https://raw.githubusercontent.com/doodlum/nexusmods-widgets/main/Ko-fi_40px_60fps.png[/img]
 [/url][/size][url=https://discord.gg/bg3mods]   [img]https://i.imgur.com/hOoJ9Yl.png[/img][/url][/center]
