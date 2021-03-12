local myname, ns = ...

ns.hiddenConfig = {
    default_icon = true,
    display = true,
    achievementsHidden = true,
    zonesHidden = true,
}

ns.RegisterPoints(1543, {
    [28384546] = { note="Under the big stone", },
    [16875504] = {},
    [16015170] = { note="Behind the portal", },
    [19243429] = {},
    [25633108] = { note="On top of Dekaris' stone, use hook", },
    [22952220] = { note="On top of the rock with candles, use hook", },
    [33102066] = { note="On top of the rock, use hook", },
    [38701943] = { note="Under the stone, south side", },
    [37544369] = { note="On the edge", },
    [41194945] = { note="On top of the cage, use hook", },
    [41314786] = { note="On top of the cage, use hook", },
    [33156481] = { note="By the wall", },
    [32586494] = { note="Inside building, you can grab it through the wall", },
    [26346862] = { note="No idea how to get there, I used door of shadows", },
    [21656684] = { note="Upstairs, on the edge", },
    [29676552] = { note="On the edge", },
    [35446747] = { note="Top of the wall, use hook", },
    [48397060] = { note="On top of the cage, use hook", },
    [54618000] = { note="Inside hound cave (cave entrance)", },
    [55067753] = { note="Inside cave", },
    [52187614] = { note="On top of the cage, use hook", },
    [57178508] = { note="Inside cave", },
    [54515845] = { note="Inside cave", },
    [23004470] = { note="Top of the platform, use hook", },
    [47166240] = { note="On the ground", },
    [52038191] = { note="On the ground", },
    [53288031] = { note="On the ground", },
    [27427225] = { note="On the ground", },
    [58095186] = { note="On the ground", },
    [23297380] = { note="On the bridge", },
    [18914631] = { note="On the platform", },
}, {
    requires_item = 184870, -- Stygia Dowser
    inbag = { 185350, 185632, any=true, }, -- [Partial / Intact] Rune Codex
    atlas = "vehicle-templeofkotmogu-greenball",
    label = "Stygia Nexus",
    quest = 63684, -- Feral Shadehound quest
})

ns.RegisterPoints(1543, {
    [24601260] = { loot={185353}, }, -- Page: Binding
    [27906060] = { loot={185352}, }, -- Page: Souls
    [48808470] = { loot={185351}, }, -- Page: Forging
}, {
    requires_item = 185350, -- Partial Rune Codex
    inbag = 185632, -- Intact Rune Codex
    minimap = true,
    icon = true,
    quest = 63684, -- Feral Shadehound quest
})

ns.RegisterPoints(1543, {
    [35604180] = { -- Soulforger's Tools
        item = 185473,
        note = "Loot from {npc:166398:Soulforger Rhovus}, use to make {item:185474}",
        requires_item = 185632, -- Intact Rune Codex
    },
    [20206700] = { --Soulsteel Anvil
        npc = 177392,
        atlas = "repair",
        requires_item = 185473, -- Soulforger's Tools
    },
}, {
    minimap = true,
    inbag = {185474, 185471, 185475, any=true}, -- Armored Husk, Willing Wolf Soul, Feral Shadehound
    quest = 63684, -- Feral Shadehound quest
})

ns.RegisterPoints(1543, {
    [35302720] = {},
    [19105210] = {},
    [40002200] = {},
    [52801430] = {},
}, {
    npc = 177195, -- Stray Soul
    item = 185471, -- Willing Wolf Soul
    atlas = "poi-soulspiritghost",
    note = "Wanders the length of Gorgoa: the River of Souls, walking from south to north then despawning",
    requires_item = {185474}, -- Armored Husk
    inbag = {185471, 185475, any=true}, -- Willing Wolf Soul, Feral Shadehound
    quest = 63684, -- Feral Shadehound quest
})

ns.RegisterPoints(1543, {
    [45104830] = {
        label = "Binding Altar",
        note = "Bind the soul to the husk.",
        atlas = "reagents",
        minimap = true,
        requires_item = 185471, -- Willing Wolf Soul
        inbag = 185475, -- Feral Shadehound
        quest = 63684, -- Feral Shadehound quest
    },
})
