local addonName, NS = ...

NS.RuleEngine = {}
local RuleEngine = NS.RuleEngine

-----------------------------------------------------------
-- Rule-Based Category Engine
-- Purpose: Apply user-defined rules to categorize items
-----------------------------------------------------------

-- Rule storage
RuleEngine.rules = {}
RuleEngine.defaultRules = {}

--- Condition evaluators
local Conditions = {
    -- Item quality check
    quality = function(item, value)
        return item.quality == value
    end,

    qualityMin = function(item, value)
        return (item.quality or 0) >= value
    end,

    qualityMax = function(item, value)
        return (item.quality or 0) <= value
    end,

    -- Item type check
    itemType = function(item, value)
        if not item.link then return false end
        local _, _, _, _, _, itemType = GetItemInfo(item.link)
        return itemType == value
    end,

    subType = function(item, value)
        if not item.link then return false end
        local _, _, _, _, _, _, subType = GetItemInfo(item.link)
        return subType == value
    end,

    -- Equipment slot
    equipSlot = function(item, value)
        if not item.link then return false end
        local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(item.link)
        return equipLoc == value
    end,

    -- Item level range
    iLevelMin = function(item, value)
        return (item.iLevel or 0) >= value
    end,

    iLevelMax = function(item, value)
        return (item.iLevel or 0) <= value
    end,

    -- Name pattern
    nameContains = function(item, value)
        if not item.link then return false end
        local name = GetItemInfo(item.link)
        if not name then return false end
        return string.find(string.lower(name), string.lower(value), 1, true) ~= nil
    end,

    -- Tooltip pattern
    tooltipContains = function(item, value)
        -- Scan tooltip for text
        if not item.link then return false end

        local tooltipName = "ZenBagsRuleScanTooltip"
        local tooltip = _G[tooltipName]
        if not tooltip then
            tooltip = CreateFrame("GameTooltip", tooltipName, UIParent, "GameTooltipTemplate")
            tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        end

        tooltip:ClearLines()
        tooltip:SetHyperlink(item.link)

        for i = 1, tooltip:NumLines() do
            local left = _G[tooltipName.."TextLeft"..i]
            if left then
                local text = left:GetText()
                if text and string.find(string.lower(text), string.lower(value), 1, true) then
                    return true
                end
            end
        end

        return false
    end,

    -- Specific item ID
    itemID = function(item, value)
        return item.itemID == value
    end,

    -- Bind status (from tooltip)
    bindStatus = function(item, value)
        return RuleEngine:CheckBindStatus(item) == value
    end,
}

--- Check bind status from tooltip
function RuleEngine:CheckBindStatus(item)
    if not item.link then return "unknown" end

    local tooltipName = "ZenBagsRuleScanTooltip"
    local tooltip = _G[tooltipName]
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", tooltipName, UIParent, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    tooltip:ClearLines()
    tooltip:SetHyperlink(item.link)

    for i = 1, math.min(tooltip:NumLines(), 5) do
        local left = _G[tooltipName.."TextLeft"..i]
        if left then
            local text = left:GetText()
            if text then
                if string.find(text, "Soulbound") then return "soulbound" end
                if string.find(text, "Binds when equipped") then return "boe" end
                if string.find(text, "Binds when picked up") then return "bop" end
                if string.find(text, "Binds when used") then return "bou" end
            end
        end
    end

    return "none"
end

--- Evaluate all conditions in a rule
function RuleEngine:EvaluateConditions(item, conditions)
    for condType, condValue in pairs(conditions) do
        local evaluator = Conditions[condType]
        if evaluator then
            if not evaluator(item, condValue) then
                return false -- AND logic - all conditions must pass
            end
        end
    end
    return true
end

--- Apply rules to categorize an item
function RuleEngine:Categorize(item)
    -- Check user rules first (higher priority)
    for _, rule in ipairs(self.rules) do
        if rule.enabled ~= false then
            if self:EvaluateConditions(item, rule.conditions) then
                return rule.category, rule.priority or 50
            end
        end
    end

    -- Check default rules
    for _, rule in ipairs(self.defaultRules) do
        if self:EvaluateConditions(item, rule.conditions) then
            return rule.category, rule.priority or 50
        end
    end

    return nil, nil -- No rule matched
end

--- Add a user rule
function RuleEngine:AddRule(name, conditions, category, priority)
    table.insert(self.rules, {
        name = name,
        conditions = conditions,
        category = category,
        priority = priority or 50,
        enabled = true,
    })
    self:SaveRules()
end

--- Remove a rule by name
function RuleEngine:RemoveRule(name)
    for i = #self.rules, 1, -1 do
        if self.rules[i].name == name then
            table.remove(self.rules, i)
        end
    end
    self:SaveRules()
end

--- Save rules to SavedVariables
function RuleEngine:SaveRules()
    if not ZenBagsDB then ZenBagsDB = {} end
    ZenBagsDB.rules = self.rules
end

--- Load rules from SavedVariables
function RuleEngine:LoadRules()
    if ZenBagsDB and ZenBagsDB.rules then
        self.rules = ZenBagsDB.rules
    end
end

--- Initialize with default rules
function RuleEngine:Init()
    self:LoadRules()

    -- Default rules (built-in)
    self.defaultRules = {
        -- Hearthstone always goes to Miscellaneous
        { conditions = { itemID = 6948 }, category = "Miscellaneous", priority = 1 },

        -- Soulbound equipment
        { conditions = { bindStatus = "soulbound", equipSlot = "INVTYPE_WEAPON" }, category = "Equipment", priority = 10 },
        { conditions = { bindStatus = "soulbound", equipSlot = "INVTYPE_CHEST" }, category = "Equipment", priority = 10 },

        -- Consumables by type
        { conditions = { itemType = "Consumable", subType = "Potion" }, category = "Consumables", priority = 20 },
        { conditions = { itemType = "Consumable", subType = "Elixir" }, category = "Consumables", priority = 20 },
        { conditions = { itemType = "Consumable", subType = "Flask" }, category = "Consumables", priority = 20 },
        { conditions = { itemType = "Consumable", subType = "Food & Drink" }, category = "Consumables", priority = 20 },
        { conditions = { itemType = "Consumable", subType = "Bandage" }, category = "Consumables", priority = 20 },

        -- Trade goods
        { conditions = { itemType = "Trade Goods" }, category = "Trade Goods", priority = 30 },

        -- Quest items
        { conditions = { itemType = "Quest" }, category = "Quest Items", priority = 5 },

        -- Recipes
        { conditions = { itemType = "Recipe" }, category = "Recipes", priority = 40 },

        -- Gems
        { conditions = { itemType = "Gem" }, category = "Gems", priority = 35 },

        -- Junk (grey items)
        { conditions = { quality = 0 }, category = "Junk", priority = 99 },
    }
end

--- Debug command
SLASH_ZENRULES1 = "/zenrules"
SlashCmdList["ZENRULES"] = function(msg)
    print("|cFF00FF00ZenBags Rules:|r")
    print(string.format("  User rules: %d", #NS.RuleEngine.rules))
    print(string.format("  Default rules: %d", #NS.RuleEngine.defaultRules))

    if msg == "list" then
        print("  |cFFFFD700User Rules:|r")
        for i, rule in ipairs(NS.RuleEngine.rules) do
            local status = rule.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"
            print(string.format("    %d. %s → %s [%s]", i, rule.name, rule.category, status))
        end
    end
end
