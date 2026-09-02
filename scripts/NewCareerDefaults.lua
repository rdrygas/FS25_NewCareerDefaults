NewCareerDefaults = {}

local MOD_NAME = g_currentModName or "FS25_NewCareerDefaults"
local DEFAULT_DAYS_PER_PERIOD = 3

-- FS25 seasonal periods start with March:
-- 1=Mar, 2=Apr, 3=May, 4=Jun, 5=Jul, 6=Aug.
local START_PERIOD = 6
local START_DAY_IN_PERIOD = 1

-- Standard new-career state in FS25.
local VANILLA_DAYS_PER_PERIOD = 1
local VANILLA_CURRENT_DAY = 6

local MARKER_FILENAME = "newCareerDefaults.xml"

NewCareerDefaults.markerPending = false

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
        return false
    end

    local xmlFile = createXMLFile("newCareerDefaults", filename, "newCareerDefaults")
    if xmlFile == 0 then
        warning("Could not create marker file: %s", filename)
        return false
    end

    setXMLInt(xmlFile, "newCareerDefaults#version", 1)
    setXMLInt(xmlFile, "newCareerDefaults#daysPerPeriod", DEFAULT_DAYS_PER_PERIOD)
    setXMLInt(xmlFile, "newCareerDefaults#startPeriod", START_PERIOD)

    saveXMLFile(xmlFile)
    delete(xmlFile)

    if fileExists(filename) then
        info("Marker saved: %s", filename)
        return true
    end

    warning("Marker save was attempted but the file is not visible: %s", filename)
    return false
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
    return environment.currentPeriod == START_PERIOD
        and environment.currentDay == VANILLA_CURRENT_DAY
        and environment.currentDayInPeriod == START_DAY_IN_PERIOD
        and environment.daysPerPeriod == VANILLA_DAYS_PER_PERIOD
        and (environment.plannedDaysPerPeriod == nil
            or environment.plannedDaysPerPeriod == VANILLA_DAYS_PER_PERIOD)
end

local function isAlreadyAppliedInitialState(environment)
    local targetCurrentDay =
        (START_PERIOD - 1) * DEFAULT_DAYS_PER_PERIOD + START_DAY_IN_PERIOD

    return environment.currentPeriod == START_PERIOD
        and environment.currentDay == targetCurrentDay
        and environment.currentDayInPeriod == START_DAY_IN_PERIOD
        and environment.daysPerPeriod == DEFAULT_DAYS_PER_PERIOD
        and environment.plannedDaysPerPeriod == DEFAULT_DAYS_PER_PERIOD
end

local function applyDefaults(mission)
    local environment = mission.environment
    local targetCurrentDay =
        (START_PERIOD - 1) * DEFAULT_DAYS_PER_PERIOD + START_DAY_IN_PERIOD

    if mission.setPlannedDaysPerPeriod ~= nil then
        mission:setPlannedDaysPerPeriod(DEFAULT_DAYS_PER_PERIOD)
        info(
            "Called FSBaseMission:setPlannedDaysPerPeriod(%d).",
            DEFAULT_DAYS_PER_PERIOD
        )
    else
        warning("FSBaseMission:setPlannedDaysPerPeriod is not available.")
    end

    if mission.missionInfo ~= nil then
        mission.missionInfo.plannedDaysPerPeriod = DEFAULT_DAYS_PER_PERIOD
    end

    environment.plannedDaysPerPeriod = DEFAULT_DAYS_PER_PERIOD
    environment.daysPerPeriod = DEFAULT_DAYS_PER_PERIOD
    environment.timeAdjustment = 1 / DEFAULT_DAYS_PER_PERIOD

    environment.currentDay = targetCurrentDay
    environment.currentDayInPeriod = START_DAY_IN_PERIOD

    -- Deliberately do not change currentMonotonicDay.
    NewCareerDefaults.markerPending = true

    info(
        "Applied: month=%s, period=%s, currentDay=%s, currentDayInPeriod=%s, daysPerPeriod=%s, plannedDaysPerPeriod=%s, timeAdjustment=%s, currentMonotonicDay=%s.",
        tostring(environment.currentMonth),
        tostring(environment.currentPeriod),
        tostring(environment.currentDay),
        tostring(environment.currentDayInPeriod),
        tostring(environment.daysPerPeriod),
        tostring(environment.plannedDaysPerPeriod),
        tostring(environment.timeAdjustment),
        tostring(environment.currentMonotonicDay)
    )

    info("Marker will be written after the next savegame save.")
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

    if isStandardNewCareerState(mission.environment) then
        applyDefaults(mission)
        return
    end

    -- This also repairs the test save made with v1.0.0.2: the calendar
    -- is already initialized, but its marker may have disappeared during save.
    if isAlreadyAppliedInitialState(mission.environment) then
        NewCareerDefaults.markerPending = true
        info("Initialized calendar detected without marker; marker will be written after the next savegame save.")
        return
    end

    info("Calendar does not match a standard new FS25 career; no changes made.")
end

local function onSaveSavegame(mission, ...)
    mission = mission or g_currentMission

    if not NewCareerDefaults.markerPending then
        return
    end

    if mission == nil then
        warning("Savegame finished but mission is nil; marker remains pending.")
        return
    end

    if writeMarker(mission) then
        NewCareerDefaults.markerPending = false
    end
end

if Mission00 ~= nil and Mission00.loadMission00Finished ~= nil then
    Mission00.loadMission00Finished =
        Utils.appendedFunction(Mission00.loadMission00Finished, onMissionLoaded)

    info("Hook installed: Mission00.loadMission00Finished.")
else
    warning("Mission00.loadMission00Finished is unavailable; hook was not installed.")
end

if FSBaseMission ~= nil and FSBaseMission.saveSavegame ~= nil then
    FSBaseMission.saveSavegame =
        Utils.appendedFunction(FSBaseMission.saveSavegame, onSaveSavegame)

    info("Hook installed: FSBaseMission.saveSavegame.")
else
    warning("FSBaseMission.saveSavegame is unavailable; save hook was not installed.")
end
