-- Vanguard Business - timed actions waiting to finish (cooking, bills, eating). Pure and testable:
-- the caller passes the current time, so nothing here reads the clock.

Pending = {}
Pending.__index = Pending

function Pending.new()
    return setmetatable({ byKey = {}, nextId = 0 }, Pending)
end

--- Starts an action for key (one per key). duration: ms before it may finish; ttl: ms before it expires.
--- Returns the action id, or nil, 'busy'.
function Pending:start(key, data, now, duration, ttl)
    if self.byKey[key] then return nil, 'busy' end
    self.nextId = self.nextId + 1
    self.byKey[key] = {
        id = self.nextId,
        data = data,
        readyAt = now + (duration or 0),
        expiresAt = ttl and (now + ttl) or nil,
    }
    return self.nextId
end

--- Completes the action when the id matches and it has run long enough (minus tolerance ms).
--- Returns data, or nil + 'none' | 'too_early' | 'expired' (expired also returns the data, once, for refunds).
function Pending:finish(key, id, now, tolerance)
    local entry = self.byKey[key]
    if not entry or entry.id ~= id then return nil, 'none' end
    if entry.expiresAt and now > entry.expiresAt then
        self.byKey[key] = nil
        return nil, 'expired', entry.data
    end
    if now + (tolerance or 0) < entry.readyAt then return nil, 'too_early' end
    self.byKey[key] = nil
    return entry.data
end

--- Drops the action and returns its data (nil if there was none).
function Pending:cancel(key)
    local entry = self.byKey[key]
    self.byKey[key] = nil
    return entry and entry.data or nil
end

--- Returns data, id of the open action for key (nothing if none).
function Pending:get(key)
    local entry = self.byKey[key]
    if not entry then return nil end
    return entry.data, entry.id
end

--- Removes expired actions and returns them as { key, data }.
function Pending:expire(now)
    local expired = {}
    for key, entry in pairs(self.byKey) do
        if entry.expiresAt and now > entry.expiresAt then
            expired[#expired + 1] = { key = key, data = entry.data }
            self.byKey[key] = nil
        end
    end
    return expired
end

--- Calls fn(key, data, id) for every open action.
function Pending:each(fn)
    for key, entry in pairs(self.byKey) do fn(key, entry.data, entry.id) end
end
