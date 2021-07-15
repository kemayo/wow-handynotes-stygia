local myname, ns = ...

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")
local HL = LibStub("AceAddon-3.0"):NewAddon(myname, "AceEvent-3.0")
-- local L = LibStub("AceLocale-3.0"):GetLocale(myname, true)
ns.HL = HL

---------------------------------------------------------
-- Data model stuff:

-- flags for whether to show minimap icons in some zones, if Blizzard ever does the treasure-map thing again
ns.map_spellids = {
    -- zone = spellid
}

ns.currencies = {
    ANIMA = {
        name = '|cffff8000' .. POWER_TYPE_ANIMA .. '|r',
        texture = select(10, GetAchievementInfo(14339)),
    },
    ARTIFACT = {
        name = '|cffff8000' .. ARTIFACT_POWER .. '|r',
        texture = select(10, GetAchievementInfo(11144)),
    }
}

ns.groups = {}

ns.points = {
    --[[ structure:
    [uiMapID] = { -- "_terrain1" etc will be stripped from attempts to fetch this
        [coord] = {
            label=[string], -- label: text that'll be the label, optional
            loot={[id]}, -- itemids
            quest=[id], -- will be checked, for whether character already has it
            currency=[id], -- currencyid
            achievement=[id], -- will be shown in the tooltip
            criteria=[id], -- modifies achievement
            junk=[bool], -- doesn't count for any achievement
            npc=[id], -- related npc id, used to display names in tooltip
            note=[string], -- some text which might be helpful
            hide_before=[id], -- hide if quest not completed
            requires_buff=[id], -- hide if player does not have buff, mostly useful for buff-based zone phasing
            requires_no_buff=[id] -- hide if player has buff, mostly useful for buff-based zone phasing
        },
    },
    --]]
}
function ns.RegisterPoints(zone, points, defaults)
    if not ns.points[zone] then
        ns.points[zone] = {}
    end
    if defaults then
        local nodeType = ns.nodeMaker(defaults)
        for coord, point in pairs(points) do
            points[coord] = nodeType(point)
        end
    end
    ns.merge(ns.points[zone], points)
end

ns.merge = function(t1, t2)
    if not t2 then return t1 end
    for k, v in pairs(t2) do
        t1[k] = v
    end
    return t1
end

ns.nodeMaker = function(defaults)
    local meta = {__index = defaults}
    return function(details)
        details = details or {}
        local meta2 = getmetatable(details)
        if meta2 and meta2.__index then
            return setmetatable(details, {__index = ns.merge(CopyTable(defaults), meta2.__index)})
        end
        return setmetatable(details, meta)
    end
end

ns.path = ns.nodeMaker{
    label = "Path to treasure",
    atlas = "poi-door", -- 'PortalPurple' / 'PortalRed'?
    path = true,
    minimap = true,
    scale = 1.1,
}

ns.lootitem = function(item)
    return type(item) == "table" and item[1] or item
end

local playerClassLocal, playerClass = UnitClass("player")
ns.playerClass = playerClass
ns.playerClassLocal = playerClassLocal
ns.playerClassColor = RAID_CLASS_COLORS[playerClass]
ns.playerName = UnitName("player")
ns.playerFaction = UnitFactionGroup("player")

---------------------------------------------------------
-- All the utility code

local cache_tooltip = _G["HNTreasuresCacheScanningTooltip"]
if not cache_tooltip then
    cache_tooltip = CreateFrame("GameTooltip", "HNTreasuresCacheScanningTooltip")
    cache_tooltip:AddFontStrings(
        cache_tooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"),
        cache_tooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText")
    )
end
local name_cache = {}
local function mob_name(id)
    if not name_cache[id] then
        -- this doesn't work with just clearlines and the setowner outside of this, and I'm not sure why
        cache_tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        cache_tooltip:SetHyperlink(("unit:Creature-0-0-0-0-%d"):format(id))
        if cache_tooltip:IsShown() then
            name_cache[id] = HNTreasuresCacheScanningTooltipTextLeft1:GetText()
        end
    end
    return name_cache[id]
end
local function quick_texture_markup(icon)
    -- needs less than CreateTextureMarkup
    return '|T' .. icon .. ':0:0:1:-1|t'
end
local completeColor = CreateColor(0, 1, 0, 1)
local incompleteColor = CreateColor(1, 0, 0, 1)
local function render_string(s)
    if type(s) == "function" then s = s() end
    return s:gsub("{(%l+):(%d+):?([^}]*)}", function(variant, id, fallback)
        id = tonumber(id)
        if variant == "item" then
            local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(id)
            if link and icon then
                return quick_texture_markup(icon) .. link
            end
        elseif variant == "spell" then
            local name, _, icon = GetSpellInfo(id)
            if name and icon then
                return quick_texture_markup(icon) .. name
            end
        elseif variant == "quest" then
            local name = C_QuestLog.GetTitleForQuestID(id)
            if not (name and name ~= "") then
                name = tostring(id)
            end
            local completed = C_QuestLog.IsQuestFlaggedCompleted(id)
            return CreateAtlasMarkup("questnormal") .. (completed and completeColor or incompleteColor):WrapTextInColorCode(name)
        elseif variant == "questid" then
            return CreateAtlasMarkup("questnormal") .. (C_QuestLog.IsQuestFlaggedCompleted(id) and completeColor or incompleteColor):WrapTextInColorCode(id)
        elseif variant == "npc" then
            local name = mob_name(id)
            if name then
                return name
            end
        elseif variant == "currency" then
            local info = C_CurrencyInfo.GetCurrencyInfo(id)
            if info then
                return quick_texture_markup(info.iconFileID) .. info.name
            end
        end
        return fallback ~= "" and fallback or (variant .. ':' .. id)
    end)
end
local function cache_string(s)
    if not s then return end
    if type(s) == "function" then s = s() end
    for variant, id, fallback in s:gmatch("{(%l+):(%d+):?([^}]*)}") do
        id = tonumber(id)
        if variant == "item" then
            C_Item.RequestLoadItemDataByID(id)
        elseif variant == "spell" then
            C_Spell.RequestLoadSpellData(id)
        elseif variant == "quest" then
            C_QuestLog.RequestLoadQuestByID(id)
        elseif variant == "npc" then
            mob_name(id)
        end
    end
end
local function cache_loot(loot)
    if not loot then return end
    for _, item in ipairs(loot) do
        C_Item.RequestLoadItemDataByID(ns.lootitem(item))
    end
end
local render_string_list
do
    local out = {}
    function render_string_list(variant, ...)
        if not ... then return "" end
        if type(...) == "table" then return render_string_list(variant, unpack(...)) end
        wipe(out)
        for i=1,select("#", ...) do
            table.insert(out, ("{%s:%d}"):format(variant, (select(i, ...))))
        end
        return render_string(string.join(", ", unpack(out)))
    end
end

local npc_texture, follower_texture, currency_texture, junk_texture
local icon_cache = {}
local trimmed_icon = function(texture)
    if not icon_cache[texture] then
        icon_cache[texture] = {
            icon = texture,
            tCoordLeft = 0.1,
            tCoordRight = 0.9,
            tCoordTop = 0.1,
            tCoordBottom = 0.9,
        }
    end
    return icon_cache[texture]
end
local atlas_texture = function(atlas, extra)
    atlas = C_Texture.GetAtlasInfo(atlas)
    if type(extra) == "number" then
        extra = {scale=extra}
    end
    return ns.merge({
        icon = atlas.file,
        tCoordLeft = atlas.leftTexCoord, tCoordRight = atlas.rightTexCoord, tCoordTop = atlas.topTexCoord, tCoordBottom = atlas.bottomTexCoord,
    }, extra)
end
ns.atlas_texture = atlas_texture
local default_textures = {
    VignetteLoot = atlas_texture("VignetteLoot", 1.2),
    VignetteLootElite = atlas_texture("VignetteLootElite", 1.3),
    Garr_TreasureIcon = atlas_texture("Garr_TreasureIcon", 2.2),
}
local function work_out_label(point)
    local fallback
    if point.label then
        return (render_string(point.label))
    end
    if point.achievement then
        if point.criteria and type(point.criteria) ~= "table" then
            local criteria = (point.criteria < 40 and GetAchievementCriteriaInfo or GetAchievementCriteriaInfoByID)(point.achievement, point.criteria)
            if criteria then
                return criteria
            end
        end
        local _, achievement = GetAchievementInfo(point.achievement)
        if achievement then
            return achievement
        end
        fallback = 'achievement:'..point.achievement
    end
    if point.follower then
        local follower = C_Garrison.GetFollowerInfo(point.follower)
        if follower then
            return follower.name
        end
        fallback = 'follower:'..point.follower
    end
    if point.npc then
        local name = mob_name(point.npc)
        if name then
            return name
        end
        fallback = 'npc:'..point.npc
    end
    if point.loot and #point.loot > 0 then
        -- handle multiples?
        local _, link = GetItemInfo(ns.lootitem(point.loot[1]))
        if link then
            return link
        end
        fallback = 'item:'..ns.lootitem(point.loot[1])
    end
    if point.currency then
        if ns.currencies[point.currency] then
            return ns.currencies[point.currency].name
        end
        local info = C_CurrencyInfo.GetCurrencyInfo(point.currency)
        if info then
            return info.name
        end
    end
    return fallback or UNKNOWN
end
local function work_out_texture(point)
    if point.texture then
        return point.texture
    end
    if point.atlas then
        if not icon_cache[point.atlas] then
            icon_cache[point.atlas] = atlas_texture(point.atlas, point.scale)
        end
        return icon_cache[point.atlas]
    end
    if ns.db.icon_item or point.icon then
        if point.loot and #point.loot > 0 then
            local texture = select(10, GetItemInfo(ns.lootitem(point.loot[1])))
            if texture then
                return trimmed_icon(texture)
            end
        end
        if point.currency then
            if ns.currencies[point.currency] then
                local texture = ns.currencies[point.currency].texture
                if texture then
                    return trimmed_icon(texture)
                end
            else
                local info = C_CurrencyInfo.GetCurrencyInfo(point.currency)
                if info then
                    return trimmed_icon(info.iconFileID)
                end
            end
        end
        if point.achievement then
            local texture = select(10, GetAchievementInfo(point.achievement))
            if texture then
                return trimmed_icon(texture)
            end
        end
    end
    if point.follower then
        if not follower_texture then
            follower_texture = atlas_texture("GreenCross", 1.5)
        end
        return follower_texture
    end
    if point.npc then
        if not npc_texture then
            npc_texture = atlas_texture("DungeonSkull", 1)
        end
        return npc_texture
    end
    if point.currency then
        if not currency_texture then
            currency_texture = atlas_texture("Auctioneer", 1.3)
        end
        return currency_texture
    end
    if point.junk then
        if not junk_texture then
            junk_texture = atlas_texture("VignetteLoot", 1)
        end
        return junk_texture
    end
    if not default_textures[ns.db.default_icon] then
        default_textures[ns.db.default_icon] = atlas_texture(ns.db.default_icon, 1.5)
    end
    return default_textures[ns.db.default_icon] or default_textures["VignetteLoot"]
end
ns.point_active = function(point)
    if point.IsActive and not point:IsActive() then
        return false
    end
    if not point.active then
        return true
    end
    if point.active.quest and not C_QuestLog.IsQuestFlaggedCompleted(point.active.quest) then
        return false
    end
    if point.active.notquest and C_QuestLog.IsQuestFlaggedCompleted(point.active.notquest) then
        return false
    end
    if point.active.requires_buff and not ns.doTest(GetPlayerAuraBySpellID, point.active.requires_buff) then
        return false
    end
    if point.active.requires_no_buff and ns.doTest(GetPlayerAuraBySpellID, point.active.requires_no_buff) then
        return false
    end
    return true
end
ns.point_upcoming = function(point)
    if point.level and UnitLevel("player") < point.level then
        return true
    elseif point.hide_before and not ns.allQuestsComplete(point.hide_before) then
        return true
    end
    return false
end
local inactive_cache = {}
local function get_inactive_texture_variant(icon)
    if not inactive_cache[icon] then
        inactive_cache[icon] = CopyTable(icon)
        if inactive_cache[icon].r then
            inactive_cache[icon].a = 0.5
        else
            inactive_cache[icon].r = 0.5
            inactive_cache[icon].g = 0.5
            inactive_cache[icon].b = 0.5
            inactive_cache[icon].a = 1
        end
    end
    return inactive_cache[icon]
end
local upcoming_cache = {}
local function get_upcoming_texture_variant(icon)
    if not upcoming_cache[icon] then
        upcoming_cache[icon] = CopyTable(icon)
        upcoming_cache[icon].r = 1
        upcoming_cache[icon].g = 0
        upcoming_cache[icon].b = 0
        upcoming_cache[icon].a = 0.7
    end
    return upcoming_cache[icon]
end
local get_point_info = function(point, isMinimap)
    if point then
        local label = work_out_label(point)
        local icon = work_out_texture(point)
        if not ns.point_active(point) then
            icon = get_inactive_texture_variant(icon)
        elseif ns.point_upcoming(point) then
            icon = get_upcoming_texture_variant(icon)
        end
        local category = "treasure"
        if point.npc then
            category = "npc"
        elseif point.junk then
            category = "junk"
        end
        if not isMinimap then
            cache_string(point.label)
            cache_string(point.note)
            cache_loot(point.loot)
        end
        return label, icon, category, point.quest, point.faction, point.scale, point.alpha or 1
    end
end
local get_point_info_by_coord = function(uiMapID, coord)
    return get_point_info(ns.points[uiMapID] and ns.points[uiMapID][coord])
end
local get_point_progress = function(point)
    if type(point.progress) == "number" then
        -- shortcut: if the progress is an objective of the tracking quest
        return select(4, GetQuestObjectiveInfo(point.quest, point.progress, false))
    elseif type(point.progress) == "table" then
        for i, q in ipairs(point.progress) do
            if not C_QuestLog.IsQuestFlaggedCompleted(q) then
                return i - 1, #point.progress
            end
        end
    else
        -- function
        return point:progress()
    end
end

local function handle_tooltip(tooltip, point)
    if point then
        -- major:
        tooltip:AddLine(work_out_label(point))
        if point.follower then
            local follower = C_Garrison.GetFollowerInfo(point.follower)
            if follower then
                local quality = BAG_ITEM_QUALITY_COLORS[follower.quality]
                tooltip:AddDoubleLine(REWARD_FOLLOWER, follower.name,
                    0, 1, 0,
                    quality.r, quality.g, quality.b
                )
                tooltip:AddDoubleLine(follower.className, UNIT_LEVEL_TEMPLATE:format(follower.level))
            end
        end
        if point.currency then
            local name
            if ns.currencies[point.currency] then
                name = ns.currencies[point.currency].name
            else
                local info = C_CurrencyInfo.GetCurrencyInfo(point.currency)
                name = info and info.name
            end
            tooltip:AddDoubleLine(CURRENCY, name or point.currency)
        end
        if point.achievement then
            local _, name, _, complete = GetAchievementInfo(point.achievement)
            tooltip:AddDoubleLine(BATTLE_PET_SOURCE_6, name or point.achievement,
                nil, nil, nil,
                complete and 0 or 1, complete and 1 or 0, 0
            )
            if point.criteria then
                if type(point.criteria) == "table" then
                    for _, criteria in ipairs(point.criteria) do
                        local criteria, _, complete = (criteria < 40 and GetAchievementCriteriaInfo or GetAchievementCriteriaInfoByID)(point.achievement, criteria)
                        tooltip:AddDoubleLine(" ", criteria,
                            nil, nil, nil,
                            complete and 0 or 1, complete and 1 or 0, 0
                        )
                    end
                else
                    local criteria, _, complete = (point.criteria < 40 and GetAchievementCriteriaInfo or GetAchievementCriteriaInfoByID)(point.achievement, point.criteria)
                    tooltip:AddDoubleLine(" ", criteria,
                        nil, nil, nil,
                        complete and 0 or 1, complete and 1 or 0, 0
                    )
                end
            elseif GetAchievementNumCriteria(point.achievement) == 1 then
                local criteria, _, complete, _, _, _, _, _, quantityString = GetAchievementCriteriaInfo(point.achievement, 1)
                if quantityString then
                    tooltip:AddDoubleLine(
                        criteria, quantityString,
                        complete and 0 or 1, complete and 1 or 0, 0,
                        complete and 0 or 1, complete and 1 or 0, 0
                    )
                else
                    tooltip:AddDoubleLine(" ", criteria,
                        nil, nil, nil,
                        complete and 0 or 1, complete and 1 or 0, 0
                    )
                end
            end
        end
        if point.note then
            tooltip:AddLine(render_string(point.note), nil, nil, nil, true)
        end
        if point.loot then
            for _, item in ipairs(point.loot) do
                local _, link, _, _, _, _, _, _, _, icon = GetItemInfo(ns.lootitem(item))
                if link then
                    local label = ENCOUNTER_JOURNAL_ITEM
                    if type(item) == "table" then
                        if item.mount then label = MOUNT
                        elseif item.toy then label = TOY
                        elseif item.pet then label = TOOLTIP_BATTLE_PET
                        end
                        -- todo: faction?
                        if item.covenant then
                            local data = C_Covenants.GetCovenantData(item.covenant)
                            -- local active = item.covenant == C_Covenants.GetActiveCovenantID()
                            if data then
                                link = TEXT_MODE_A_STRING_VALUE_TYPE:format(link, COVENANT_COLORS[item.covenant]:WrapTextInColorCode(data.name))
                            end
                        end
                        if item.class then
                            link = TEXT_MODE_A_STRING_VALUE_TYPE:format(link, RAID_CLASS_COLORS[item.class]:WrapTextInColorCode(LOCALIZED_CLASS_NAMES_FEMALE[item.class]))
                        end
                    end
                    local known = ns.itemIsKnown(item)
                    if known ~= nil and (known == true or not ns.itemRestricted(item)) then
                        link = link .. CreateAtlasMarkup(known and "common-icon-checkmark" or "common-icon-redx")
                    end
                    tooltip:AddDoubleLine(label, quick_texture_markup(icon) .. link)
                else
                    tooltip:AddDoubleLine(ENCOUNTER_JOURNAL_ITEM, SEARCH_LOADING_TEXT,
                        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b,
                        0, 1, 1
                    )
                end
            end
        end
        if point.covenant then
            local data = C_Covenants.GetCovenantData(point.covenant)
            if data then
                local active = point.covenant == C_Covenants.GetActiveCovenantID()
                tooltip:AddLine(ITEM_REQ_SKILL:format(data.name), active and 0 or 1, active and 1 or 0, 0)
            end
        end
        if point.level and point.level > UnitLevel("player") then
            tooltip:AddLine(ITEM_MIN_LEVEL:format(point.level), 1, 0, 0)
        end
        if point.hide_before and not ns.allQuestsComplete(point.hide_before) then
            tooltip:AddLine(COMMUNITY_TYPE_UNAVAILABLE, 1, 0, 0)
        end

        if point.quest and ns.db.tooltip_questid then
            tooltip:AddDoubleLine("QuestID", render_string_list("questid", point.quest), NORMAL_FONT_COLOR:GetRGB())
        end
        if point.progress then
            local fulfilled, required = get_point_progress(point)
            if fulfilled and required then
                tooltip:AddDoubleLine(PVP_PROGRESS_REWARDS_HEADER, GENERIC_FRACTION_STRING:format(fulfilled, required))
            end
        end

        if (ns.db.tooltip_item or IsShiftKeyDown()) and (point.loot or point.npc) then
            local comparison = ShoppingTooltip1

            do
                local side
                local leftPos = tooltip:GetLeft() or 0
                local rightPos = tooltip:GetRight() or 0
                local rightDist = GetScreenWidth() - rightPos

                if (leftPos and (rightDist < leftPos)) then
                    side = "left"
                else
                    side = "right"
                end

                -- see if we should slide the tooltip
                if tooltip:GetAnchorType() and tooltip:GetAnchorType() ~= "ANCHOR_PRESERVE" then
                    local totalWidth = 0
                    if ( primaryItemShown  ) then
                        totalWidth = totalWidth + comparison:GetWidth()
                    end

                    if ( (side == "left") and (totalWidth > leftPos) ) then
                        tooltip:SetAnchorType(tooltip:GetAnchorType(), (totalWidth - leftPos), 0)
                    elseif ( (side == "right") and (rightPos + totalWidth) >  GetScreenWidth() ) then
                        tooltip:SetAnchorType(tooltip:GetAnchorType(), -((rightPos + totalWidth) - GetScreenWidth()), 0)
                    end
                end

                comparison:SetOwner(tooltip, "ANCHOR_NONE")
                comparison:ClearAllPoints()

                if ( side and side == "left" ) then
                    comparison:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", 0, -10)
                else
                    comparison:SetPoint("TOPLEFT", tooltip, "TOPRIGHT", 0, -10)
                end
            end

            if point.loot and #point.loot > 0 then
                comparison:SetHyperlink(("item:%d"):format(ns.lootitem(point.loot[1])))
            elseif point.npc then
                comparison:SetHyperlink(("unit:Creature-0-0-0-0-%d"):format(point.npc))
            end
            comparison:Show()
        end
    else
        tooltip:SetText(UNKNOWN)
    end
    tooltip:Show()
end
local handle_tooltip_by_coord = function(tooltip, uiMapID, coord)
    return handle_tooltip(tooltip, ns.points[uiMapID] and ns.points[uiMapID][coord])
end

---------------------------------------------------------
-- Plugin Handlers to HandyNotes
local HLHandler = {}

function HLHandler:OnEnter(uiMapID, coord)
    local point = ns.points[uiMapID] and ns.points[uiMapID][coord]
    if point and point.route then
        if ns.points[uiMapID][point.route] then
            point = ns.points[uiMapID][point.route]
        end
        ns.RouteWorldMapDataProvider:HighlightRoute(point, uiMapID, coord)
    end
    local tooltip = GameTooltip
    if ns.db.tooltip_pointanchor or self:GetParent() == Minimap then
        if self:GetCenter() > UIParent:GetCenter() then -- compare X coordinate
            tooltip:SetOwner(self, "ANCHOR_LEFT")
        else
            tooltip:SetOwner(self, "ANCHOR_RIGHT")
        end
    else
        tooltip:SetOwner(WorldMapFrame.ScrollContainer, "ANCHOR_NONE")
        local x, y = HandyNotes:getXY(coord)
        if y < 0.5 then
            tooltip:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer)
        else
            tooltip:SetPoint("TOPLEFT", WorldMapFrame.ScrollContainer)
        end
    end
    handle_tooltip_by_coord(tooltip, uiMapID, coord)
end

local function createWaypoint(button, uiMapID, coord)
    if TomTom then
        local x, y = HandyNotes:getXY(coord)
        TomTom:AddWaypoint(uiMapID, x, y, {
            title = get_point_info_by_coord(uiMapID, coord),
            persistent = nil,
            minimap = true,
            world = true
        })
    end
end

local function hideNode(button, uiMapID, coord)
    ns.hidden[uiMapID][coord] = true
    HL:Refresh()
end

local function closeAllDropdowns()
    CloseDropDownMenus(1)
end

do
    local currentZone, currentCoord
    local function generateMenu(button, level)
        if (not level) then return end
        local info = UIDropDownMenu_CreateInfo()
        if (level == 1) then
            -- Create the title of the menu
            info.isTitle      = 1
            info.text         = "HandyNotes - " .. myname:gsub("HandyNotes_", "")
            info.notCheckable = 1
            UIDropDownMenu_AddButton(info, level)
            wipe(info)

            if TomTom then
                -- Waypoint menu item
                info.text = "Create waypoint"
                info.notCheckable = 1
                info.func = createWaypoint
                info.arg1 = currentZone
                info.arg2 = currentCoord
                UIDropDownMenu_AddButton(info, level)
                wipe(info)
            end

            -- Hide menu item
            info.text         = "Hide node"
            info.notCheckable = 1
            info.func         = hideNode
            info.arg1         = currentZone
            info.arg2         = currentCoord
            UIDropDownMenu_AddButton(info, level)
            wipe(info)

            -- Close menu item
            info.text         = "Close"
            info.func         = closeAllDropdowns
            info.notCheckable = 1
            UIDropDownMenu_AddButton(info, level)
            wipe(info)
        end
    end
    local HL_Dropdown = CreateFrame("Frame", myname.."DropdownMenu")
    HL_Dropdown.displayMode = "MENU"
    HL_Dropdown.initialize = generateMenu

    function HLHandler:OnClick(button, down, uiMapID, coord)
        currentZone = uiMapID
        currentCoord = coord
        -- given we're in a click handler, this really *should* exist, but just in case...
        local point = ns.points[currentZone] and ns.points[currentZone][currentCoord]
        if point and button == "RightButton" and not down then
            ToggleDropDownMenu(1, nil, HL_Dropdown, self, 0, 0)
        end
    end
end

function HLHandler:OnLeave(uiMapID, coord)
    GameTooltip:Hide()
    ShoppingTooltip1:Hide()

    local point = ns.points[uiMapID] and ns.points[uiMapID][coord]
    if point and point.route then
        if ns.points[uiMapID][point.route] then
            point = ns.points[uiMapID][point.route]
        end
        ns.RouteWorldMapDataProvider:UnhighlightRoute(point, uiMapID, coord)
    end
end

do
    -- This is a custom iterator we use to iterate over every node in a given zone
    local currentZone, isMinimap
    local function iter(t, prestate)
        if not t then return nil end
        local state, value = next(t, prestate)
        while state do -- Have we reached the end of this zone?
            if value and ns.should_show_point(state, value, currentZone, isMinimap) then
                local label, icon, _, _, _, scale, alpha = get_point_info(value, isMinimap)
                scale = (scale or 1) * (icon and icon.scale or 1) * ns.db.icon_scale
                return state, nil, icon, scale, ns.db.icon_alpha * alpha
            end
            state, value = next(t, state) -- Get next data
        end
        return nil, nil, nil, nil
    end
    function HLHandler:GetNodes2(uiMapID, minimap)
        -- Debug("GetNodes2", uiMapID, minimap)
        currentZone = uiMapID
        isMinimap = minimap
        if minimap and ns.map_spellids[uiMapID] then
            if ns.map_spellids[uiMapID] == true then
                return iter
            end
            if GetPlayerAuraBySpellID(ns.map_spellids[uiMapID]) then
                return iter
            end
        end
        return iter, ns.points[uiMapID], nil
    end
end

---------------------------------------------------------
-- Addon initialization, enabling and disabling

function HL:OnInitialize()
    -- Set up our database
    if self.defaultsOverride then
        ns.merge(ns.defaults.profile, ns.defaultsOverride)
    end
    self.db = LibStub("AceDB-3.0"):New(myname.."DB", ns.defaults)
    ns.db = self.db.profile
    ns.hidden = self.db.char.hidden
    -- Initialize our database with HandyNotes
    HandyNotes:RegisterPluginDB(myname:gsub("HandyNotes_", ""), HLHandler, ns.options)

    -- Watch for events... but mitigate spammy events by bucketing in Refresh
    self:RegisterEvent("LOOT_CLOSED", "RefreshOnEvent")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "RefreshOnEvent")
    self:RegisterEvent("CRITERIA_EARNED", "RefreshOnEvent")
    self:RegisterEvent("BAG_UPDATE", "RefreshOnEvent")
    self:RegisterEvent("QUEST_TURNED_IN", "RefreshOnEvent")
    self:RegisterEvent("SHOW_LOOT_TOAST", "RefreshOnEvent")
    self:RegisterEvent("GARRISON_FOLLOWER_ADDED", "RefreshOnEvent")
    -- This is just constantly firing, so it's kinda useless:
    -- self:RegisterEvent("CRITERIA_UPDATE", "Refresh")

    if ns.SetupMapOverlay then
        ns.SetupMapOverlay()
    end

    if ns.RouteWorldMapDataProvider then
        WorldMapFrame:AddDataProvider(ns.RouteWorldMapDataProvider)
    end
end

do
    local bucket = CreateFrame("Frame")
    bucket.elapsed = 0
    bucket:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed > 1.5 then
            self.elapsed = 0
            self:Hide()
            HL:Refresh()
        end
    end)
    function HL:Refresh()
        HL:SendMessage("HandyNotes_NotifyUpdate", myname:gsub("HandyNotes_", ""))
        if ns.RouteWorldMapDataProvider then
            ns.RouteWorldMapDataProvider:RefreshAllData()
        end
    end
    function HL:RefreshOnEvent(event)
        bucket:Show()
    end
end
