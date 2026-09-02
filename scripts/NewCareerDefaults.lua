NewCareerDefaults = {}

local MOD_NAME = g_currentModName or "FS25_NewCareerDefaults"

-- Configuration
local DEFAULT_DAYS_PER_PERIOD = 3

-- FS25 seasonal periods are counted from March:
-- 1=March, 2=April, 3=May, 4=June, 5=July, 6=August.
local START_PERIOD = 6
local START_MONTH = 8
local START_DAY_IN_PERIOD = 1

-- Standard FS25 new-career calendar state.
local VANILLA_DAYS_PER_PERIOD = 1
local VANILLA_CURRENT_DAY = 6

local MARKER_FILENAME = "newCareerDefaults.xml"
local MAX_WAIT_TIME_MS = 10000

local function logInfo(message, ...)
    Logging.info("[%s] " .. message, MOD_NAME, ...)
end

local function logWarning(message, ...)
    Logging.warning("[%s] " .. message, MOD_NAME, ...)
end

local function getSavegameDirectory(mission)
    if mission == nil or mission.missionInfo == nil then
        return nil
    end

    local directory = mission.missionInfo.savegameDirectory

    if (directory == nil or directory == "") and mission.missionInfo.savegameIndex ~= nil then
        directory = string.format(
            "%ssavegame%d",
            getUserProfileAppPath(),
            mission.missionInfo.savegameIndex
        )
    end

    if directory == nil or directory == "" then
        return nil
    end

    local lastChar = string.sub(directory, -1)
    if lastChar ~= "/" and lastChar ~= "\\" then
        directory = directory .. "/"
    end

    return directory
end

local function getMarkerFilename(mission)
    local directory = getSavegameDirectory(mission)
    if directory == nil then
        return nil
    end

    return directory .. MARKER_FILENAME
end

local function hasMarker(mission)
    local filename = getMarkerFilename(mission)
    return filename ~= nil and fileExists(filename)
end

local function writeMarker(mission)
    local filename = getMarkerFilename(mission)
    if filename == nil then
        logWarning("Could not determine savegame directory; marker file was not written.")
        return
    end

    local xmlFile = createXMLFile("newCareerDefaults", filename, "newCareerDefaults")
    if xmlFile == 0 then
        logWarning("Could not create marker file '%s'.", filename)
        return
    end

    setXMLInt(xmlFile, "newCareerDefaults#version", 1)
    setXMLInt(xmlFile, "newCareerDefaults#daysPerPeriod", DEFAULT_DAYS_PER_PERIOD)
    setXMLInt(xmlFile, "newCareerDefaults#startPeriod", START_PERIOD)
    saveXMLFile(xmlFile)
    delete(xmlFile)
end

local function isStandardNewCareerState(mission)
    local environment = mission.environment
    local missionInfo = mission.missionInfo

    if environment == nil or missionInfo == nil then
        return false
    end

    local plannedDaysPerPeriod =
        missionInfo.plannedDaysPerPeriod
        or environment.plannedDaysPerPeriod
        or environment.daysPerPeriod

    return environment.daysPerPeriod == VANILLA_DAYS_PER_PERIOD
        and plannedDaysPerPeriod == VANILLA_DAYS_PER_PERIOD
        and environment.currentDay == VANILLA_CURRENT_DAY
        and environment.currentDayInPeriod == START_DAY_IN_PERIOD
        and environment.currentPeriod == START_PERIOD
        and environment.currentMonth == START_MONTH
end

local function applyDefaults(mission)
    local environment = mission.environment
    local targetCurrentDay =
        (START_PERIOD - 1) * DEFAULT_DAYS_PER_PERIOD + START_DAY_IN_PERIOD

    -- Use the game's own settings function when available so the setting shown
    -- in the menu and the savegame setting are updated normally.
    if mission.setPlannedDaysPerPeriod ~= nil then
        mission:setPlannedDaysPerPeriod(DEFAULT_DAYS_PER_PERIOD)
    end

    -- Keep the saved/planned value explicit as well.
    mission.missionInfo.plannedDaysPerPeriod = DEFAULT_DAYS_PER_PERIOD
    environment.plannedDaysPerPeriod = DEFAULT_DAYS_PER_PERIOD

    -- Apply the new period length immediately instead of waiting for the next
    -- season boundary.
    environment.daysPerPeriod = DEFAULT_DAYS_PER_PERIOD

    -- FS25 uses this as a season-length normalizer.
    environment.timeAdjustment = 1 / DEFAULT_DAYS_PER_PERIOD

    -- Keep the career on the first day of August under the new period length.
    environment.currentDay = targetCurrentDay
    environment.currentDayInPeriod = START_DAY_IN_PERIOD

    -- Intentionally do NOT modify currentMonotonicDay. Weather uses the
    -- monotonic timeline and changing it can make the forecast/time jump.

    writeMarker(mission)

    logInfo(
        "Applied new career defaults: %d days/month, August day %d (currentDay=%d).",
        DEFAULT_DAYS_PER_PERIOD,
        START_DAY_IN_PERIOD,
        targetCurrentDay
    )
end

function NewCareerDefaults:loadMap()
    self.checked = false
    self.waitTime = 0
end

function NewCareerDefaults:update(dt)
    if self.checked then
        return
    end

    local mission = g_currentMission
    if mission == nil or mission.environment == nil or mission.missionInfo == nil then
        self.waitTime = self.waitTime + dt

        if self.waitTime >= MAX_WAIT_TIME_MS then
            self.checked = true
            logWarning("Mission environment was not ready; no changes were made.")
        end

        return
    end

    if mission.getIsServer ~= nil and not mission:getIsServer() then
        self.checked = true
        return
    end

    local environment = mission.environment
    if environment.currentDay == nil
        or environment.currentDayInPeriod == nil
        or environment.currentPeriod == nil
        or environment.currentMonth == nil
        or environment.daysPerPeriod == nil then

        self.waitTime = self.waitTime + dt
        return
    end

    self.checked = true

    if hasMarker(mission) then
        logInfo("Defaults were already applied to this savegame; no changes made.")
        return
    end

    if not isStandardNewCareerState(mission) then
        logInfo(
            "Existing or non-standard career detected; no changes made. "
                .. "Calendar: month=%s period=%s day=%s dayInPeriod=%s daysPerPeriod=%s.",
            tostring(environment.currentMonth),
            tostring(environment.currentPeriod),
            tostring(environment.currentDay),
            tostring(environment.currentDayInPeriod),
            tostring(environment.daysPerPeriod)
        )
        return
    end

    applyDefaults(mission)
end

function NewCareerDefaults:deleteMap()
    self.checked = false
    self.waitTime = 0
end

addModEventListener(NewCareerDefaults)
