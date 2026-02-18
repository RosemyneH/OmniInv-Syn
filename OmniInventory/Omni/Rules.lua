-- =============================================================================
-- OmniInventory Custom Rule Engine
-- =============================================================================
-- Purpose: Allow advanced users to define custom categorization rules
-- using a simple declarative format or sandboxed Lua expressions.
-- =============================================================================

local addonName, Omni = ...

Omni.Rules = {}
local Rules = Omni.Rules

-- =============================================================================
-- Rule Storage
-- =============================================================================

local compiledRules = {}  -- Cached compiled rule functions

-- =============================================================================
-- Rule Definition
-- =============================================================================

--[[
Rule format:
{
    name = "My Raid Consumables",
    enabled = true,
    priority = 5,
    category = "Raid Consumables",
    conditions = {
        { field = "itemType", operator = "equals", value = "Consumable" },
        { field = "name", operator = "contains", value = "Flask" },
    },
    -- OR simple Lua expression:
    expression = "itemType == 'Consumable' and name:match('Flask')",
}
]]

-- =============================================================================
-- Condition Operators
-- =============================================================================

local OPERATORS = {
    equals = function(a, b)
        return a == b
    end,

    not_equals = function(a, b)
        return a ~= b
    end,

    contains = function(a, b)
        if type(a) ~= "string" or type(b) ~= "string" then
            return false
        end
        return string.find(string.lower(a), string.lower(b), 1, true) ~= nil
    end,

    starts_with = function(a, b)
        if type(a) ~= "string" or type(b) ~= "string" then
            return false
        end
        return string.sub(string.lower(a), 1, #b) == string.lower(b)
    end,

    greater_than = function(a, b)
        return (tonumber(a) or 0) > (tonumber(b) or 0)
    end,

    less_than = function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0)
    end,

    in_list = function(a, b)
        if type(b) ~= "table" then return false end
        for _, v in ipairs(b) do
            if a == v then return true end
        end
        return false
    end,
    in_list = function(a, b)
        if type(b) ~= "table" then return false end
        for _, v in ipairs(b) do
            if a == v then return true end
        end
        return false
    end,
}

function Rules:GetRuleTypes()
    -- Map operators to user-friendly names and input types
    return {
        { id = "equals", name = "Equals", type = "text" },
        { id = "not_equals", name = "Not Equals", type = "text" },
        { id = "contains", name = "Contains", type = "text" },
        { id = "starts_with", name = "Starts With", type = "text" },
        { id = "greater_than", name = "Greater Than", type = "number" },
        { id = "less_than", name = "Less Than", type = "number" },
        { id = "in_list", name = "In List (comma sep)", type = "text" },
    }
end

-- =============================================================================
-- Field Extractors
-- =============================================================================

local function GetFieldValue(itemInfo, field)
    if not itemInfo then return nil end

    -- Direct fields
    if itemInfo[field] then
        return itemInfo[field]
    end

    -- Computed fields
    if field == "name" then
        if itemInfo.hyperlink then
            local name = GetItemInfo(itemInfo.hyperlink)
            return name
        end
        return nil
    end

    if field == "itemType" or field == "itemSubType" then
        if itemInfo.hyperlink then
            local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemInfo.hyperlink)
            return field == "itemType" and itemType or itemSubType
        end
        return nil
    end

    if field == "iLvl" or field == "itemLevel" then
        if itemInfo.hyperlink then
            local _, _, _, iLvl = GetItemInfo(itemInfo.hyperlink)
            return iLvl
        end
        return nil
    end

    return nil
end

-- =============================================================================
-- Rule Evaluation
-- =============================================================================

local function EvaluateCondition(itemInfo, condition)
    local fieldValue = GetFieldValue(itemInfo, condition.field)
    local operator = OPERATORS[condition.operator]

    if not operator then
        return false
    end

    return operator(fieldValue, condition.value)
end

local function EvaluateConditions(itemInfo, conditions, matchType)
    matchType = matchType or "all"  -- "all" (AND) or "any" (OR)

    if not conditions or #conditions == 0 then
        return false
    end

    for _, condition in ipairs(conditions) do
        local result = EvaluateCondition(itemInfo, condition)

        if matchType == "any" and result then
            return true
        elseif matchType == "all" and not result then
            return false
        end
    end

    return matchType == "all"
end

-- =============================================================================
-- Sandboxed Lua Expression Execution
-- =============================================================================

local SAFE_ENV = {
    -- Safe string functions
    string = {
        find = string.find,
        match = string.match,
        lower = string.lower,
        upper = string.upper,
        sub = string.sub,
        len = string.len,
    },
    -- Safe math functions
    math = {
        floor = math.floor,
        ceil = math.ceil,
        abs = math.abs,
        min = math.min,
        max = math.max,
    },
    -- Comparison
    tonumber = tonumber,
    tostring = tostring,
    type = type,
}

local function CompileExpression(expression)
    if not expression or expression == "" then
        return nil, "Empty expression"
    end

    -- Wrap in return statement
    local code = "return function(item) return " .. expression .. " end"

    -- Compile with loadstring
    local chunk, err = loadstring(code)
    if not chunk then
        return nil, "Syntax error: " .. (err or "unknown")
    end

    -- Execute in sandboxed environment
    setfenv(chunk, SAFE_ENV)

    local ok, result = pcall(chunk)
    if not ok then
        return nil, "Execution error: " .. (result or "unknown")
    end

    return result, nil
end

local function EvaluateExpression(itemInfo, expression)
    -- Check cache first
    if not compiledRules[expression] then
        local func, err = CompileExpression(expression)
        if not func then
            print("|cFFFF0000OmniInventory Rules|r: " .. err)
            return false
        end
        compiledRules[expression] = func
    end

    -- Build item context for expression
    local context = {
        itemID = itemInfo.itemID,
        quality = itemInfo.quality,
        stackCount = itemInfo.stackCount,
        isBound = itemInfo.isBound,
        bagID = itemInfo.bagID,
        slotID = itemInfo.slotID,
    }

    -- Add computed fields
    if itemInfo.hyperlink then
        local name, _, _, iLvl, _, itemType, itemSubType = GetItemInfo(itemInfo.hyperlink)
        context.name = name or ""
        context.iLvl = iLvl or 0
        context.itemType = itemType or ""
        context.itemSubType = itemSubType or ""
    end

    -- Execute compiled expression
    local ok, result = pcall(compiledRules[expression], context)
    if not ok then
        return false
    end

    return result == true
end

-- =============================================================================
-- Rule Matching
-- =============================================================================

function Rules:MatchRule(itemInfo, rule)
    if not rule or not rule.enabled then
        return false
    end

    -- Check expression first (if defined)
    if rule.expression and rule.expression ~= "" then
        return EvaluateExpression(itemInfo, rule.expression)
    end

    -- Check conditions
    if rule.conditions and #rule.conditions > 0 then
        return EvaluateConditions(itemInfo, rule.conditions, rule.matchType)
    end

    return false
end

function Rules:FindMatchingRule(itemInfo)
    local rules = self:GetAllRules()

    -- Sort by priority
    table.sort(rules, function(a, b)
        return (a.priority or 99) < (b.priority or 99)
    end)

    for _, rule in ipairs(rules) do
        if self:MatchRule(itemInfo, rule) then
            return rule
        end
    end

    return nil
end

-- =============================================================================
-- Rule Management
-- =============================================================================

function Rules:GetAllRules()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.customRules = OmniInventoryDB.customRules or {}
    return OmniInventoryDB.customRules
end

function Rules:AddRule(rule)
    if not rule or not rule.name then return false end

    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.customRules = OmniInventoryDB.customRules or {}

    -- Generate ID
    rule.id = rule.id or tostring(GetTime()) .. "_" .. math.random(1000, 9999)
    rule.enabled = rule.enabled ~= false
    rule.priority = rule.priority or 50

    table.insert(OmniInventoryDB.customRules, rule)

    -- Clear compiled cache for this expression
    if rule.expression then
        compiledRules[rule.expression] = nil
    end

    if Omni.Events then Omni.Events:FireEvent("RULES_CHANGED") end
    return true
end

function Rules:RemoveRule(ruleId)
    local rules = self:GetAllRules()

    for i, rule in ipairs(rules) do
        if rule.id == ruleId then
            -- Clear compiled cache
            if rule.expression then
                compiledRules[rule.expression] = nil
            end
            table.remove(rules, i)
            if Omni.Events then Omni.Events:FireEvent("RULES_CHANGED") end
            return true
        end
    end

    return false
end

function Rules:UpdateRule(ruleId, updates)
    local rules = self:GetAllRules()

    for _, rule in ipairs(rules) do
        if rule.id == ruleId then
            for k, v in pairs(updates) do
                rule[k] = v
            end
            -- Clear compiled cache if expression changed
            if updates.expression then
                compiledRules[rule.expression] = nil
            end
            if Omni.Events then Omni.Events:FireEvent("RULES_CHANGED") end
            return true
        end
    end

    return false
end

function Rules:ToggleRule(ruleId)
    local rules = self:GetAllRules()

    for _, rule in ipairs(rules) do
        if rule.id == ruleId then
            rule.enabled = not rule.enabled
            if Omni.Events then Omni.Events:FireEvent("RULES_CHANGED") end
            return true
        end
    end

    return false
end

-- =============================================================================
-- Preset Rules
-- =============================================================================

function Rules:LoadPresets()
    -- Only load if no rules exist
    if #self:GetAllRules() > 0 then
        return
    end

    -- Example preset rules
    local presets = {
        {
            name = "Hearthstone",
            priority = 1,
            category = "Hearthstone",
            conditions = {
                { field = "itemID", operator = "equals", value = 6948 },
            },
        },
        {
            name = "Food & Drink",
            priority = 20,
            category = "Consumables: Food",
            conditions = {
                { field = "itemSubType", operator = "in_list", value = { "Food & Drink", "Consumable" } },
            },
        },
    }

    for _, preset in ipairs(presets) do
        preset.isPreset = true
        self:AddRule(preset)
    end
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Rules:Init()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.customRules = OmniInventoryDB.customRules or {}

    -- Optionally load presets
    -- self:LoadPresets()
end

print("|cFF00FF00OmniInventory|r: Rules engine loaded")
