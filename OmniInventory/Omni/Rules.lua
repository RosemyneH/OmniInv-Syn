-- =============================================================================
-- OmniInventory Category Rule Engine
-- =============================================================================
-- Purpose: Compile and evaluate player-editable Lua category rules.
-- =============================================================================

local addonName, Omni = ...

Omni.Rules = {}
local Rules = Omni.Rules

local defaultRules = {}
local compiledRules = {}

local BASE_ENV = {
    assert = assert,
    error = error,
    ipairs = ipairs,
    next = next,
    pairs = pairs,
    pcall = pcall,
    select = select,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    unpack = unpack,
    math = math,
    string = string,
    table = table,
}

local function TrimCategoryName(name)
    name = tostring(name or "")
    return (string.gsub(name, "^%s*(.-)%s*$", "%1"))
end

local function CopyRule(rule)
    if type(rule) ~= "table" then return nil end
    return {
        category = rule.category,
        enabled = rule.enabled ~= false,
        priority = tonumber(rule.priority) or 1000,
        script = tostring(rule.script or ""),
        description = tostring(rule.description or ""),
        userModified = rule.userModified == true,
    }
end

local function GetStore()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    if type(OmniInventoryDB.global.categoryRules) ~= "table" then
        OmniInventoryDB.global.categoryRules = {}
    end
    return OmniInventoryDB.global.categoryRules
end

local function ClearCompiled(categoryName)
    if categoryName then
        compiledRules[categoryName] = nil
    else
        compiledRules = {}
    end
end

local function CompileScript(categoryName, script)
    script = tostring(script or "")
    if script == "" then
        return nil, "Rule script is empty."
    end

    local cached = compiledRules[categoryName]
    if cached and cached.script == script then
        return cached.func
    end

    local chunk, err = loadstring("return function()\n" .. script .. "\nend")
    if not chunk then
        return nil, err or "Rule syntax error."
    end

    setfenv(chunk, BASE_ENV)
    local ok, func = pcall(chunk)
    if not ok then
        return nil, func or "Rule compile failed."
    end
    if type(func) ~= "function" then
        return nil, "Rule script did not compile into a function."
    end

    compiledRules[categoryName] = {
        script = script,
        func = func,
    }
    return func
end

local function BuildEnv(itemInfo, helpers)
    local env = {}
    for key, value in pairs(BASE_ENV) do
        env[key] = value
    end
    if type(helpers) == "table" then
        for key, value in pairs(helpers) do
            env[key] = value
        end
    end
    env.item = itemInfo
    return env
end

local function CompareRules(a, b)
    local priorityA = tonumber(a.priority) or 1000
    local priorityB = tonumber(b.priority) or 1000
    if priorityA ~= priorityB then
        return priorityA < priorityB
    end
    return tostring(a.category) < tostring(b.category)
end

function Rules:RegisterDefaultCategoryRules(rules)
    defaultRules = {}
    for categoryName, rule in pairs(rules or {}) do
        local category = TrimCategoryName(categoryName)
        if category ~= "" then
            defaultRules[category] = CopyRule(rule) or {}
            defaultRules[category].category = category
        end
    end
    self:EnsureDefaultCategoryRules()
end

function Rules:EnsureDefaultCategoryRules()
    local store = GetStore()
    for categoryName, rule in pairs(defaultRules) do
        if type(store[categoryName]) ~= "table" then
            local copy = CopyRule(rule)
            copy.category = categoryName
            copy.userModified = false
            store[categoryName] = copy
        end
    end
end

function Rules:EnsureCategoryRule(categoryName, priority)
    categoryName = TrimCategoryName(categoryName)
    if categoryName == "" then return nil end

    local store = GetStore()
    if type(store[categoryName]) ~= "table" then
        local defaultRule = defaultRules[categoryName]
        if defaultRule then
            store[categoryName] = CopyRule(defaultRule)
        else
            store[categoryName] = {
                category = categoryName,
                enabled = false,
                priority = tonumber(priority) or 1000,
                script = "",
                description = "Player-defined category rule.",
                userModified = false,
            }
        end
    end
    store[categoryName].category = categoryName
    if store[categoryName].enabled == nil then
        store[categoryName].enabled = true
    end
    if not store[categoryName].priority then
        store[categoryName].priority = tonumber(priority) or 1000
    end
    if not store[categoryName].script then
        store[categoryName].script = ""
    end
    return store[categoryName]
end

function Rules:GetCategoryRule(categoryName)
    local rule = self:EnsureCategoryRule(categoryName)
    return CopyRule(rule)
end

function Rules:GetDefaultCategoryRule(categoryName)
    categoryName = TrimCategoryName(categoryName)
    return CopyRule(defaultRules[categoryName])
end

function Rules:GetAllCategoryRules()
    self:EnsureDefaultCategoryRules()
    local rules = {}
    for categoryName, rule in pairs(GetStore()) do
        if type(rule) == "table" then
            rule.category = rule.category or categoryName
            rules[#rules + 1] = rule
        end
    end
    table.sort(rules, CompareRules)
    return rules
end

function Rules:ValidateScript(script)
    local func, err = CompileScript("__validation", script)
    compiledRules.__validation = nil
    return func ~= nil, err
end

function Rules:SetCategoryRuleScript(categoryName, script)
    categoryName = TrimCategoryName(categoryName)
    local ok, err = self:ValidateScript(script)
    if not ok then
        return false, err
    end

    local rule = self:EnsureCategoryRule(categoryName)
    if not rule then return false, "Missing category." end

    rule.script = tostring(script or "")
    rule.enabled = true
    rule.userModified = true
    ClearCompiled(categoryName)
    return true
end

function Rules:SetCategoryRuleEnabled(categoryName, enabled)
    local rule = self:EnsureCategoryRule(categoryName)
    if not rule then return false end

    rule.enabled = enabled == true
    rule.userModified = true
    return true
end

function Rules:SetCategoryRulePriority(categoryName, priority)
    local value = tonumber(priority)
    if not value then
        return false, "Priority must be a number."
    end

    local rule = self:EnsureCategoryRule(categoryName)
    if not rule then return false, "Missing category." end

    rule.priority = value
    rule.userModified = true
    return true
end

function Rules:ResetCategoryRule(categoryName)
    categoryName = TrimCategoryName(categoryName)
    if categoryName == "" then return false end

    local store = GetStore()
    local defaultRule = defaultRules[categoryName]
    if defaultRule then
        local copy = CopyRule(defaultRule)
        copy.category = categoryName
        copy.userModified = false
        store[categoryName] = copy
    else
        store[categoryName] = {
            category = categoryName,
            enabled = false,
            priority = 1000,
            script = "",
            description = "Player-defined category rule.",
            userModified = false,
        }
    end
    ClearCompiled(categoryName)
    return true
end

function Rules:RenameCategoryRule(oldName, newName)
    oldName = TrimCategoryName(oldName)
    newName = TrimCategoryName(newName)
    if oldName == "" or newName == "" or oldName == newName then return false end

    local store = GetStore()
    if type(store[oldName]) ~= "table" or store[newName] ~= nil then
        return false
    end

    store[newName] = store[oldName]
    store[oldName] = nil
    store[newName].category = newName
    ClearCompiled(oldName)
    ClearCompiled(newName)
    return true
end

function Rules:DeleteCategoryRule(categoryName)
    categoryName = TrimCategoryName(categoryName)
    if categoryName == "" then return false end

    local store = GetStore()
    store[categoryName] = nil
    ClearCompiled(categoryName)
    return true
end

function Rules:EvaluateCategoryRule(rule, itemInfo, helpers)
    if type(rule) ~= "table" or rule.enabled == false or tostring(rule.script or "") == "" then
        return false
    end

    local categoryName = rule.category or "?"
    local func, err = CompileScript(categoryName, rule.script)
    if not func then
        rule.lastError = err
        return false
    end

    setfenv(func, BuildEnv(itemInfo, helpers))
    local ok, result = pcall(func)
    if not ok then
        rule.lastError = result
        return false
    end

    rule.lastError = nil
    return result == true
end

function Rules:FindMatchingCategory(itemInfo, helpers, isCategoryVisible)
    for _, rule in ipairs(self:GetAllCategoryRules()) do
        local categoryName = rule.category
        local visible = type(isCategoryVisible) ~= "function" or isCategoryVisible(categoryName)
        if visible and self:EvaluateCategoryRule(rule, itemInfo, helpers) then
            return categoryName, rule
        end
    end
    return nil
end

function Rules:Init()
    GetStore()
end

print("|cFF00FF00OmniInventory|r: Category Rules loaded")
