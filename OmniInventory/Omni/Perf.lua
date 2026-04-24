-- =============================================================================
-- OmniInventory Lightweight Performance Profiler
-- =============================================================================

local addonName, Omni = ...

Omni.Perf = {}
local Perf = Omni.Perf

local metrics = {}
local stackByTag = {}
local bucketCounters = {}

local function nowMs()
    if debugprofilestop then
        return debugprofilestop()
    end
    if GetTime then
        return GetTime() * 1000
    end
    return 0
end

local function ensureDb()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.settings = OmniInventoryDB.char.settings or {}
    return OmniInventoryDB.char.settings
end

function Perf:IsEnabled()
    return Omni._perfEnabled == true
end

function Perf:SetEnabled(enabled)
    local settings = ensureDb()
    local on = enabled == true
    settings.debugPerf = on
    Omni._perfEnabled = on
end

function Perf:SyncEnabledFromSettings()
    local settings = ensureDb()
    Omni._perfEnabled = settings.debugPerf == true
    return Omni._perfEnabled
end

local function ensureMetric(key)
    local metric = metrics[key]
    if metric then
        return metric
    end
    metric = {
        key = key,
        count = 0,
        sumMs = 0,
        maxMs = 0,
        samples = {},
        sampleCap = 120,
        context = {},
    }
    metrics[key] = metric
    return metric
end

function Perf:RecordValue(key, elapsedMs, context)
    if not self:IsEnabled() then
        return
    end
    if not key or type(elapsedMs) ~= "number" then
        return
    end
    local metric = ensureMetric(key)
    metric.count = metric.count + 1
    metric.sumMs = metric.sumMs + elapsedMs
    if elapsedMs > metric.maxMs then
        metric.maxMs = elapsedMs
    end
    metric.samples[#metric.samples + 1] = elapsedMs
    if #metric.samples > metric.sampleCap then
        table.remove(metric.samples, 1)
    end
    if type(context) == "table" then
        for k, v in pairs(context) do
            metric.context[k] = v
        end
    end
end

function Perf:Begin(key)
    if not self:IsEnabled() or not key then
        return nil
    end
    local startedAt = nowMs()
    stackByTag[key] = startedAt
    return startedAt
end

function Perf:End(key, token, context)
    if not self:IsEnabled() or not key then
        return
    end
    local startedAt = token or stackByTag[key]
    if not startedAt then
        return
    end
    local elapsed = nowMs() - startedAt
    self:RecordValue(key, elapsed, context)
    if not token then
        stackByTag[key] = nil
    end
end

function Perf:CountBucket(eventName, fired)
    if not self:IsEnabled() or not eventName then
        return
    end
    local entry = bucketCounters[eventName]
    if not entry then
        entry = { seen = 0, fired = 0 }
        bucketCounters[eventName] = entry
    end
    if fired then
        entry.fired = entry.fired + 1
    else
        entry.seen = entry.seen + 1
    end
end

local function percentileFromSamples(samples, p)
    if not samples or #samples == 0 then
        return 0
    end
    local ordered = {}
    for i = 1, #samples do
        ordered[i] = samples[i]
    end
    table.sort(ordered)
    local idx = math.ceil(#ordered * p)
    if idx < 1 then idx = 1 end
    if idx > #ordered then idx = #ordered end
    return ordered[idx]
end

local function round2(v)
    return math.floor((v or 0) * 100 + 0.5) / 100
end

function Perf:GetSnapshot()
    local out = {
        meta = {
            addon = addonName or "OmniInventory",
            tsMs = nowMs(),
            version = Omni.version or "unknown",
        },
        metrics = {},
        buckets = {},
    }

    for k, v in pairs(metrics) do
        local avg = 0
        if v.count > 0 then
            avg = v.sumMs / v.count
        end
        out.metrics[k] = {
            count = v.count,
            avgMs = round2(avg),
            p95Ms = round2(percentileFromSamples(v.samples, 0.95)),
            maxMs = round2(v.maxMs),
            context = v.context,
        }
    end

    for eventName, info in pairs(bucketCounters) do
        out.buckets[eventName] = {
            seen = info.seen or 0,
            fired = info.fired or 0,
        }
    end

    return out
end

local function encodeScalar(v)
    local t = type(v)
    if t == "number" then
        return tostring(v)
    end
    if t == "boolean" then
        return v and "true" or "false"
    end
    if t == "string" then
        local s = string.gsub(v, "\\", "\\\\")
        s = string.gsub(s, "\"", "\\\"")
        return "\"" .. s .. "\""
    end
    return "null"
end

local function encodeTable(tbl)
    local isArray = true
    local maxN = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" then
            isArray = false
            break
        end
        if k > maxN then
            maxN = k
        end
    end

    if isArray then
        local parts = {}
        for i = 1, maxN do
            local value = tbl[i]
            if type(value) == "table" then
                parts[#parts + 1] = encodeTable(value)
            else
                parts[#parts + 1] = encodeScalar(value)
            end
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    local keys = {}
    for k, _ in pairs(tbl) do
        keys[#keys + 1] = tostring(k)
    end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
        local value = tbl[key]
        local encodedValue = (type(value) == "table") and encodeTable(value) or encodeScalar(value)
        parts[#parts + 1] = "\"" .. key .. "\":" .. encodedValue
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function Perf:ExportJson()
    return encodeTable(self:GetSnapshot())
end

function Perf:PrintReport()
    local snapshot = self:GetSnapshot()
    print("|cFF00FF00OmniInventory|r perf report:")
    local keys = {}
    for key, _ in pairs(snapshot.metrics) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    if #keys == 0 then
        print("  (no samples recorded)")
    else
        for _, key in ipairs(keys) do
            local m = snapshot.metrics[key]
            print(string.format("  %s -> n=%d avg=%.2fms p95=%.2fms max=%.2fms",
                key, m.count or 0, m.avgMs or 0, m.p95Ms or 0, m.maxMs or 0))
        end
    end
end

function Perf:Reset()
    metrics = {}
    stackByTag = {}
    bucketCounters = {}
end

print("|cFF00FF00OmniInventory|r: Perf profiler loaded")
