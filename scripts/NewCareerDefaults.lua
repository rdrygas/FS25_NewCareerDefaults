NewCareerDefaults = {}

local MOD_NAME = g_currentModName or "FS25_NewCareerDefaults"
local DEFAULT_DAYS_PER_PERIOD = 3

-- FS25 seasonal periods start with March:
-- 1=Mar, 2=Apr, 3=May, 4=Jun, 5=Jul, 6=Aug.
local START_PERIOD = 6
local START_MONTH = 8
local START_DAY_IN_PERIOD = 1

-- Standard new-career state in FS25.
local VANILLA_DAYS_PER_PERIOD = 1
local VANILLA_CURRENT_DAY = 6

local MARKER_FILENAME = "newCareerDefaults.xml"

local function info(fmt, ...)
    print(string.format("Info: [%s] %s", MOD_NAME, string.format(fmt, ...)))
end

local function warning(fmt, ...)
    print(string.format("Warning: [%s] %s", MOD_NAME, string.format(fmt, ...)))
end

info("Script loaded.")

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
        warning("Could not determine savegame directory; marker was not written.")
        return
    end

    local xmlFile = createXMLFile("newCareerDefaults", filename, "newCareerDefaults")
    if xmlFile == 0 then
        warning("Could not create marker file: %s", filename)
        return
    end

    setXMLInt(xmlFile, "newCareerDefaults#version", 1)
    setXMLInt(xmlFile, "newCareerDefaults#daysPerPeriod", DEFAULT_DAYS_PER_PERIOD)
    setXMLInt(xmlFile, "newCareerDefaults#startPeriod", START_PERIOD)

    saveXMLFile(xmlFile)
    delete(xmlFile)

    info("Marker written: %s", filename)
end

local function dumpCalendar(environment)
    info(
        "Calendar before check: month=%s, period=%s, currentDay=%s, currentDayInPeriod=%s, daysPerPeriod=%s, plannedDaysPerPeriod=%s, timeAdjustment=%s, currentMonotonicDay=%s",
        tostring(environment.currentMonth),
        tostring(environment.currentPeriod),
        tostring(environment.currentDay),
        tostring(environment.currentDayInPeriod),
        tostring(environment.daysPerPeriod),
        tostring(environment.plannedDaysPerPeriod),
        tostring(environment.timeAdjustment),
        tostring(environment.currentMonotonicDay)
    )
end

local function isStandardNewCareerState(environment)
    return environment.currentMonth == START_MONTH
        and environment.currentPeriod == START_PERIOD
        and environment.currentDay == VANILLA_CURRENT_DAY
        and environment.currentDayInPeriod == START_DAY_IN_PERIOD
        and environment.daysPerPeriod == VANILLA_DAYS_PER_PERIOD
        and (environment.plannedDaysPerPeriod == nil
            or environment.plannedDaysPerPeriod == VANILLA_DAYS_PER_PERIOD)
end

local function applyDefaults(mission)
    local environment = mission.environment
    local targetCurrentDay =
        (START_PERIOD - 1) * DEFAULT_DAYS_PER_PERIOD + START_DAY_IN_PERIOD

    -- The game exposes this setter on FSBaseMission. It normally plans
    -- the new value for the next season.
    if mission.setPlannedDaysPerPeriod ~= nil then
        mission:setPlannedDaysPerPeriod(DEFAULT_DAYS_PER_PERIOD)
        info("Called FSBaseMission:setPlannedDaysPerPeriod(%d).", DEFAULT_DAYS_PER_PERIOD)
    else
        warning("FSBaseMission:setPlannedDaysPerPeriod is not available.")
    end

    -- Apply the setting immediately for a brand-new career.
    if mission.missionInfo ~= nil then
        mission.missionInfo.plannedDaysPerPeriod = DEFAULT_DAYS_PER_PERIOD
    end

    environment.plannedDaysPerPeriod = DEFAULT_DAYS_PER_PERIOD
    environment.daysPerPeriod = DEFAULT_DAYS_PER_PERIOD
    environment.timeAdjustment = 1 / DEFAULT_DAYS_PER_PERIOD

    -- Preserve "first day of August" after changing the number of days
    -- represented by each seasonal period.
    environment.currentDay = targetCurrentDay
    environment.currentDayInPeriod = START_DAY_IN_PERIOD

    -- Deliberately leave currentMonotonicDay untouched.
    writeMarker(mission)

    info(
        "Applied: daysPerPeriod=%d, plannedDaysPerPeriod=%d, month=%d, period=%d, currentDay=%d, currentDayInPeriod=%d.",
        environment.daysPerPeriod,
        environment.plannedDaysPerPeriod,
        environment.currentMonth,
        environment.currentPeriod,
        environment.currentDay,
        environment.currentDayInPeriod
    )
end

local function onMissionLoaded(mission, ...)
    info("Mission00.loadMission00Finished called.")

    mission = mission or g_currentMission

    if mission == nil then
        warning("Mission is nil; no changes made.")
        return
    end

    if mission.environment == nil then
        warning("Mission environment is nil; no changes made.")
        return
    end

    dumpCalendar(mission.environment)

    if mission.getIsServer ~= nil and not mission:getIsServer() then
        info("Not the server instance; no changes made.")
        return
    end

    if hasMarker(mission) then
        info("Marker already exists; no changes made.")
        return
    end

    if not isStandardNewCareerState(mission.environment) then
        info("Calendar does not match a standard new FS25 career; no changes made.")
        return
    end

    applyDefaults(mission)
end

if Mission00 ~= nil and Mission00.loadMission00Finished ~= nil then
    Mission00.loadMission00Finished =
        Utils.appendedFunction(Mission00.loadMission00Finished, onMissionLoaded)

    info("Hook installed: Mission00.loadMission00Finished.")
else
    warning("Mission00.loadMission00Finished is unavailable; hook was not installed.")
end
