--[[
    FS25_NewCareerDefaults
    ======================

    Purpose
    -------
    This mod changes the calendar of a standard, newly created Farming Simulator 25
    career from the vanilla default of 1 day per month to 3 days per month, while
    keeping the career on the first day of August.

    The mod is intentionally conservative:
      * it only recognizes the standard initial FS25 calendar state;
      * it applies the change only once;
      * it does not change currentMonotonicDay;
      * it stores a small marker file in the savegame after the first normal save;
      * it does not continuously enforce the setting after initialization.

    The implementation and the values used below were verified in-game with FS25.
]]

NewCareerDefaults = {}

local MOD_NAME = g_currentModName or "FS25_NewCareerDefaults"

-- ============================================================================
-- Configuration
-- ============================================================================

-- Number of days per month that a newly initialized career should use.
--
-- The rest of the calendar conversion is calculated from this value, so changing
-- it to another supported FS25 value does not require manually recalculating
-- currentDay below.
local DEFAULT_DAYS_PER_PERIOD = 3

-- FS25 seasonal periods are numbered starting with March:
--   1 = March
--   2 = April
--   3 = May
--   4 = June
--   5 = July
--   6 = August
--
-- A standard FS25 career starts on the first day of August, hence period 6.
local START_PERIOD = 6
local START_DAY_IN_PERIOD = 1

-- ============================================================================
-- Vanilla new-career signature
-- ============================================================================

-- These values describe the standard FS25 state observed immediately after a
-- newly created career has finished loading, before this mod changes anything.
--
-- currentMonth is deliberately NOT used. At Mission00.loadMission00Finished it
-- can still be nil, even though currentPeriod and all other calendar fields are
-- already initialized correctly.
local VANILLA_DAYS_PER_PERIOD = 1
local VANILLA_CURRENT_DAY = 6
local VANILLA_CURRENT_MONOTONIC_DAY = 6

-- Name of the small per-savegame marker written after the first normal save.
-- Its presence prevents the initialization logic from ever being reapplied to
-- that savegame later.
local MARKER_FILENAME = "newCareerDefaults.xml"

-- The flag is set after initialization and cleared only after the marker has
-- successfully been written during a normal game save.
NewCareerDefaults.markerPending = false

-- ============================================================================
-- Logging helpers
-- ============================================================================

local function logInfo(message, ...)
    Logging.info("[%s] " .. message, MOD_NAME, ...)
end

local function logWarning(message, ...)
    Logging.warning("[%s] " .. message, MOD_NAME, ...)
end

-- ============================================================================
-- Savegame path / marker helpers
-- ============================================================================

---Returns the savegame directory currently used by FS25.
---
---During an ordinary load this is normally the real savegame directory
---(for example savegame1). During saving FS25 temporarily redirects
---missionInfo.savegameDirectory to "tempsavegame"; this is exactly what we want,
---because files created there are moved together with the rest of the completed
---save into the real savegame directory.
---@param mission table
---@return string|nil
local function getSavegameDirectory(mission)
    if mission == nil or mission.missionInfo == nil then
        return nil
    end

    local directory = mission.missionInfo.savegameDirectory

    -- Fallback for cases where savegameDirectory is not populated yet.
    -- This path is mainly useful while loading an existing save.
    if (directory == nil or directory == "")
        and mission.missionInfo.savegameIndex ~= nil then

        directory = string.format(
            "%ssavegame%d",
            getUserProfileAppPath(),
            mission.missionInfo.savegameIndex
        )
    end

    if directory == nil or directory == "" then
        return nil
    end

    -- Normalize the path so MARKER_FILENAME can simply be appended.
    local lastCharacter = string.sub(directory, -1)
    if lastCharacter ~= "/" and lastCharacter ~= "\\" then
        directory = directory .. "/"
    end

    return directory
end

---Returns the full path of the marker file for the current savegame.
---@param mission table
---@return string|nil
local function getMarkerFilename(mission)
    local directory = getSavegameDirectory(mission)

    if directory == nil then
        return nil
    end

    return directory .. MARKER_FILENAME
end

---Checks whether this savegame has already been initialized by the mod.
---@param mission table
---@return boolean
local function hasMarker(mission)
    local filename = getMarkerFilename(mission)
    return filename ~= nil and fileExists(filename)
end

---Writes the initialization marker into the directory currently used by the
---game's save process.
---
---The marker is intentionally NOT created during mission loading. A new FS25
---career is saved through a temporary "tempsavegame" directory; writing the
---marker from the save hook ensures it becomes part of the completed save and
---is transferred to savegameN together with the standard game files.
---@param mission table
---@return boolean
local function writeMarker(mission)
    local filename = getMarkerFilename(mission)

    if filename == nil then
        logWarning("Could not determine the savegame directory; marker was not written.")
        return false
    end

    local xmlFile = createXMLFile(
        "newCareerDefaults",
        filename,
        "newCareerDefaults"
    )

    if xmlFile == 0 then
        logWarning("Could not create marker file '%s'.", filename)
        return false
    end

    -- The file is intentionally small. These values are informational; marker
    -- existence itself is what prevents the initialization from running again.
    setXMLInt(xmlFile, "newCareerDefaults#version", 1)
    setXMLInt(
        xmlFile,
        "newCareerDefaults#daysPerPeriod",
        DEFAULT_DAYS_PER_PERIOD
    )
    setXMLInt(xmlFile, "newCareerDefaults#startPeriod", START_PERIOD)

    saveXMLFile(xmlFile)
    delete(xmlFile)

    if not fileExists(filename) then
        logWarning(
            "Marker save was attempted, but the file is not visible at '%s'.",
            filename
        )
        return false
    end

    logInfo("Initialization marker saved.")
    return true
end

-- ============================================================================
-- Calendar-state detection
-- ============================================================================

---Returns true only for the standard, untouched FS25 new-career calendar state.
---
---currentMonotonicDay is part of the signature on purpose. Without it, an older
---career that happens to return to August 1 with one day per month could look
---similar to a new save. The monotonic value remains greater in an older career.
---@param environment table
---@return boolean
local function isStandardNewCareerState(environment)
    return environment.currentPeriod == START_PERIOD
        and environment.currentDay == VANILLA_CURRENT_DAY
        and environment.currentDayInPeriod == START_DAY_IN_PERIOD
        and environment.daysPerPeriod == VANILLA_DAYS_PER_PERIOD
        and environment.currentMonotonicDay == VANILLA_CURRENT_MONOTONIC_DAY
        and (
            environment.plannedDaysPerPeriod == nil
            or environment.plannedDaysPerPeriod == VANILLA_DAYS_PER_PERIOD
        )
end

---Recognizes a save that already has the desired initial calendar state but is
---missing the marker file.
---
---This is useful for test saves created with earlier versions of this mod and is
---also a harmless recovery path if the marker was removed manually. No calendar
---values are changed in this branch; the marker is merely recreated on save.
---@param environment table
---@return boolean
local function isAlreadyInitializedState(environment)
    local targetCurrentDay =
        (START_PERIOD - 1) * DEFAULT_DAYS_PER_PERIOD + START_DAY_IN_PERIOD

    return environment.currentPeriod == START_PERIOD
        and environment.currentDay == targetCurrentDay
        and environment.currentDayInPeriod == START_DAY_IN_PERIOD
        and environment.daysPerPeriod == DEFAULT_DAYS_PER_PERIOD
        and environment.plannedDaysPerPeriod == DEFAULT_DAYS_PER_PERIOD
        and environment.currentMonotonicDay == VANILLA_CURRENT_MONOTONIC_DAY
end

-- ============================================================================
-- Calendar initialization
-- ============================================================================

---Applies the desired calendar settings to a verified new career.
---
---For August (period 6) and 3 days per month:
---
---    currentDay = (6 - 1) * 3 + 1 = 16
---
---The first five seasonal periods therefore occupy days 1..15 and the first day
---of August becomes day 16. currentDayInPeriod stays 1, so the HUD still shows
---the first day of August.
---
---currentMonotonicDay is deliberately left unchanged. It represents the
---monotonic world/weather timeline and does not need to be remapped merely
---because the number of days represented by a period changes.
---@param mission table
local function applyDefaults(mission)
    local environment = mission.environment

    local targetCurrentDay =
        (START_PERIOD - 1) * DEFAULT_DAYS_PER_PERIOD + START_DAY_IN_PERIOD

    -- Use the game's normal savegame-setting API first. This makes the new
    -- plannedDaysPerPeriod value visible to the standard settings system and
    -- ensures the choice is persisted by FS25.
    if mission.setPlannedDaysPerPeriod ~= nil then
        mission:setPlannedDaysPerPeriod(DEFAULT_DAYS_PER_PERIOD)
    else
        -- The direct assignments below still provide a fallback, but this API is
        -- expected to exist in the tested FS25 environment.
        logWarning(
            "FSBaseMission:setPlannedDaysPerPeriod is unavailable; applying values directly."
        )
    end

    -- Keep both the mission setting and the environment in sync immediately.
    -- Normally FS25 treats plannedDaysPerPeriod as a future change; for a brand-
    -- new career we intentionally apply it now, before gameplay has progressed.
    if mission.missionInfo ~= nil then
        mission.missionInfo.plannedDaysPerPeriod = DEFAULT_DAYS_PER_PERIOD
    end

    environment.plannedDaysPerPeriod = DEFAULT_DAYS_PER_PERIOD
    environment.daysPerPeriod = DEFAULT_DAYS_PER_PERIOD

    -- FS25 uses timeAdjustment as a normalization factor for the selected number
    -- of days per period. For N days per month the appropriate value is 1 / N.
    environment.timeAdjustment = 1 / DEFAULT_DAYS_PER_PERIOD

    -- Remap the season-relative currentDay so the career remains on August 1.
    environment.currentDay = targetCurrentDay
    environment.currentDayInPeriod = START_DAY_IN_PERIOD

    -- DO NOT change environment.currentMonotonicDay.
    --
    -- Keeping it at the vanilla starting value preserves the internal monotonic
    -- timeline used by systems such as weather while only changing the calendar
    -- representation of the seasonal period.

    -- The marker is written later, from the save hook, because at save time FS25
    -- uses tempsavegame and then moves the complete result to savegameN.
    NewCareerDefaults.markerPending = true

    logInfo(
        "New career initialized: %d days/month, starting on August 1.",
        DEFAULT_DAYS_PER_PERIOD
    )
end

-- ============================================================================
-- FS25 lifecycle callbacks
-- ============================================================================

---Runs after Mission00 has finished loading.
---
---At this point environment.currentMonth can still be nil, but the fields used by
---the detection logic (currentPeriod, currentDay, currentDayInPeriod, etc.) are
---already available and were verified in-game.
---@param mission table
local function onMissionLoaded(mission, ...)
    -- Always reset per-mission transient state. This prevents a pending marker
    -- from one unsaved career from leaking into another save loaded later in the
    -- same FS25 process.
    NewCareerDefaults.markerPending = false

    mission = mission or g_currentMission

    if mission == nil or mission.environment == nil or mission.missionInfo == nil then
        logWarning("Mission data is incomplete; no initialization was performed.")
        return
    end

    -- The mod is designed for single-player. This guard also keeps all disk and
    -- calendar changes server-authoritative if the code is ever loaded elsewhere.
    if mission.getIsServer ~= nil and not mission:getIsServer() then
        return
    end

    -- Once a save has a marker, the mod never touches its calendar again.
    if hasMarker(mission) then
        return
    end

    if isStandardNewCareerState(mission.environment) then
        applyDefaults(mission)
        return
    end

    -- Recovery/compatibility path: the calendar is already exactly in the state
    -- produced by this mod, but the marker is missing. Do not alter the calendar;
    -- simply recreate the marker during the next normal save.
    if isAlreadyInitializedState(mission.environment) then
        NewCareerDefaults.markerPending = true
    end
end

---Runs after FS25 performs its normal save operation.
---
---During this callback missionInfo.savegameDirectory points to tempsavegame.
---Writing the marker there makes it part of the atomic save that FS25 later
---moves into the real savegameN directory.
---@param mission table
local function onSaveSavegame(mission, ...)
    if not NewCareerDefaults.markerPending then
        return
    end

    mission = mission or g_currentMission

    if mission == nil then
        logWarning("Save completed without a valid mission; marker remains pending.")
        return
    end

    if writeMarker(mission) then
        NewCareerDefaults.markerPending = false
    end
end

---Clears transient state when leaving a mission.
---
---This is an additional safeguard for the case where a newly initialized career
---is exited without being saved and another savegame is opened in the same game
---session.
local function onMissionDeleted(...)
    NewCareerDefaults.markerPending = false
end

-- ============================================================================
-- Hook installation
-- ============================================================================

-- Mission00.loadMission00Finished is late enough for the calendar environment to
-- be initialized, but still early enough to change the initial career state
-- before normal gameplay begins.
if Mission00 ~= nil and Mission00.loadMission00Finished ~= nil then
    Mission00.loadMission00Finished =
        Utils.appendedFunction(
            Mission00.loadMission00Finished,
            onMissionLoaded
        )
else
    logWarning(
        "Mission00.loadMission00Finished is unavailable; initialization hook was not installed."
    )
end

-- The marker must be written as part of FS25's normal save flow. In a new career
-- this hook sees the temporary save directory (tempsavegame), which is later
-- promoted by the game to the real savegameN directory.
if FSBaseMission ~= nil and FSBaseMission.saveSavegame ~= nil then
    FSBaseMission.saveSavegame =
        Utils.appendedFunction(
            FSBaseMission.saveSavegame,
            onSaveSavegame
        )
else
    logWarning(
        "FSBaseMission.saveSavegame is unavailable; marker save hook was not installed."
    )
end

-- Reset the transient flag when leaving a career.
if FSBaseMission ~= nil and FSBaseMission.delete ~= nil then
    FSBaseMission.delete =
        Utils.appendedFunction(
            FSBaseMission.delete,
            onMissionDeleted
        )
end
