-- N-TRACS Core [Track]

---[package]予約ステートです
---@enum BookType
BookType = {
    NoBook = 0,
    Temporary = 1,
    RouteLock = 2,
    Destination = 3,
    RouteOver = 4
}

---軌道回路に関するものです
---@class Track:NtracsObject
---@field  relatedLever Lever | nil
---@field book BookType
---@field direction RouteDirection
---@field private timer number
---@field private beforeRouteLockItem Track | Lever | nil
---@field private short boolean
Track = Track or {}

---抽象軌道回路データを作成します
---@return Track
function Track.new()
    local obj = CreateInstance(NtracsObject.new(), Track)
    obj.name = "Track"
    return obj
end

---抽象軌道回路データを作成します
---@param itemName string 抽象軌道回路名称です
---@return Track
function Track.overWrite(self, itemName)
    self = self or CreateInstance(self, Track)
    self.name = "Track"
    self.itemName = itemName
    self.relatedLever = nil
    self.book = BookType.NoBook
    self.direction = RouteDirection.None
    self.timer = 0
    self.beforeRouteLockItem = nil
    return self
end

---[package]
---@package
---@param lever Lever
function Track.bookTemporary(self, lever)
    if self.book ~= BookType.RouteOver then
        self.relatedLever = lever
        self.book = BookType.Temporary
        self.direction = lever.direction
    end
end

---[package]
---@package
---@param lever Lever
function Track.bookRouteLock(self, lever, routeLockBefore)
    self.relatedLever = lever
    self.beforeRouteLockItem = routeLockBefore
    self.book = BookType.RouteLock
    self.direction = lever.direction
end

---[package]
---@package
---@param lever Lever
function Track.bookDestination(self, lever, routeLockBefore)
    self.relatedLever = lever
    self.beforeRouteLockItem = routeLockBefore
    self.book = BookType.Destination
    self.direction = lever.direction
    self.timer = lever.overrunTime
end

---[package]
---@package
---@param lever Lever
function Track.bookOverrun(self, lever)
    self.relatedLever = lever
    self.beforeRouteLockItem = lever.destination
    self.book = BookType.RouteOver
    self.direction = lever.direction
end

---[package]
---@package
---@param lever Lever
---@return boolean
function Track.isReadyToBookTemporary(self, lever)
    return (self.book == BookType.NoBook) or (self.book == BookType.Temporary and self.relatedLever == lever) or
        (self.book == BookType.RouteOver and self.direction == lever.direction)
end

---[package]
---@package
---@param lever Lever
---@return boolean
function Track.isBookedTemporary(self, lever)
    return (self.book == BookType.Temporary and self.relatedLever == lever) or
        (self.book == BookType.RouteOver and self.direction == lever.direction)
end

---[package]
---@package
---@param lever Lever
---@return boolean
function Track.isRouteLock(self, lever)
    return self.relatedLever == lever and self.book == BookType.RouteLock
end

---[package]
---@package
---@param lever Lever
---@return boolean
function Track.isOverrunLock(self, lever)
    return (self.relatedLever == lever and self.book == BookType.RouteOver) or
        (self.book == BookType.RouteLock and self.direction == lever.direction)
end

---[package]
---@package
---@param temporaryIsNotLocked boolean
---@return boolean
function Track.isLocked(self, temporaryIsNotLocked)
    if temporaryIsNotLocked then
        return (self.book ~= BookType.NoBook) and (self.book ~= BookType.Temporary)
    else
        return self.book ~= BookType.NoBook
    end
end

---[package]
---@package
---@return boolean
function Track.underRouteLock_n(self)
    return (self.book == BookType.Destination and self.timer < 0) or
        (self.book == BookType.NoBook or self.book == BookType.Temporary)
end

---ポリモーフィズム的に取り扱う。ひとつ前のNtracsObjectを調べる。
---@param item nil | NtracsObject
---@return boolean
function CheckUnlockRouteLock(item)
    if item == nil then return true end

    --クラス判別の必要があるため、内部データnameを取得
    ---@diagnostic disable-next-line: invisible
    if item.name == "Track" then
        --Track型が確定しているためエラー回避
        ---@diagnostic disable-next-line
        return Track.underRouteLock_n(item)
        --クラス判別の必要があるため、内部データnameを取得
        ---@diagnostic disable-next-line: invisible
    elseif item.name == "Lever" then
        --Lever型が確定しているためエラー回避
        ---@diagnostic disable-next-line
        return Lever.underRouteLock_n(item)
    end
    return false
end

---抽象軌道回路内に在線があればtrueを返却します
---@return boolean
function Track.isShort(self)
    return self.short
end

---processを呼び出す前に実行してください。状態を設定します
---@param isShort boolean
function Track.beforeProcess(self, isShort)
    self.short = isShort
end

---毎ループごとに呼び出してください
---@param deltaTick number
function Track.process(self, deltaTick)
    if self.book == BookType.RouteLock or self.book == BookType.RouteOver then
        if (not self.short) and CheckUnlockRouteLock(self.beforeRouteLockItem) then
            self.book = BookType.NoBook
        end
    elseif self.book == BookType.Destination then
        if CheckUnlockRouteLock(self.beforeRouteLockItem) then
            self.timer = math.max(self.timer - deltaTick, -1)
            if not self.short then
                self.book = BookType.NoBook
            end
        end
    elseif self.book == BookType.NoBook then
        -- do nothing
    elseif self.book == BookType.Temporary then
        if not Lever.getInput(self.relatedLever) then
            self.book = BookType.NoBook
        end
    else
        if self.itemName then
            error("Book mode is wrong: " .. tostring(self.itemName))
        end
    end
end
