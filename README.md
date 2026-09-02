# FS25 New Career Defaults

A small script mod for **Farming Simulator 25** that changes the default calendar of a newly created standard career to **3 days per month**, while keeping the starting date at **August 1**.

## Default behavior

With the mod enabled when a standard new career is created:

- the career still starts on **August 1**;
- the HUD shows the **first day of August**;
- **Days per month** is immediately set to **3**;
- the setting is registered through the normal FS25 savegame-settings mechanism;
- the calendar conversion is performed only during initialization;
- after initialization, the mod does **not** continuously force the value and the player remains free to change the setting later.

The mod is intended for **single-player PC use**.

## Design assumptions

The implementation follows several deliberately conservative assumptions.

### 1. Only the standard initial FS25 calendar state should be changed

The mod does not simply change every savegame that has it enabled.

A standard newly created FS25 career was verified in-game to reach `Mission00.loadMission00Finished` with the following values:

```text
currentPeriod          = 6
currentDay             = 6
currentDayInPeriod     = 1
daysPerPeriod          = 1
plannedDaysPerPeriod   = 1
currentMonotonicDay    = 6
currentMonth           = nil
```

The mod checks the meaningful initialized values above before applying anything.

`currentMonth` is intentionally not part of the test because it can still be `nil` at this point in the FS25 loading sequence. `currentPeriod = 6` is sufficient to identify August in the seasonal calendar.

Including `currentMonotonicDay = 6` makes the test safer: an older career that later returns to August 1 is not mistaken for a brand-new career merely because its visible calendar happens to look similar.

### 2. August 1 must remain August 1 after changing the period length

FS25 seasonal periods are numbered from March:

| Period | Month |
| ---: | --- |
| 1 | March |
| 2 | April |
| 3 | May |
| 4 | June |
| 5 | July |
| 6 | August |

For `3` days per period, the first day of August is therefore:

```text
currentDay = (period - 1) × daysPerPeriod + dayInPeriod
currentDay = (6 - 1) × 3 + 1
currentDay = 16
```

The mod changes:

```text
currentDay:         6 -> 16
currentDayInPeriod: 1 -> 1
```

The result is still **August 1**, but under a 3-day-per-month calendar.

### 3. The normal FS25 setting mechanism should still be used

The mod first calls:

```lua
mission:setPlannedDaysPerPeriod(3)
```

This lets FS25 register the new value as its normal savegame setting.

Because FS25 normally treats `plannedDaysPerPeriod` as a future calendar change, the mod then synchronizes the relevant environment values immediately. This is safe here because the operation is performed only at the untouched beginning of a new career.

### 4. `timeAdjustment` must match the new period length

FS25 uses `environment.timeAdjustment` as a normalization factor for the selected period length.

For three days per month the mod therefore sets:

```lua
environment.timeAdjustment = 1 / 3
```

### 5. `currentMonotonicDay` must not be changed

The mod deliberately leaves:

```lua
environment.currentMonotonicDay
```

untouched.

This value represents a monotonic internal timeline used by systems such as weather. The goal of the mod is to change the seasonal calendar representation, not to move the underlying world timeline forward.

## One-time initialization marker

After the calendar is initialized, the mod creates:

```text
newCareerDefaults.xml
```

inside the savegame.

The marker prevents the initialization logic from ever being reapplied to that savegame.

### Why the file is written during saving

FS25 creates a normal save through a temporary directory named:

```text
tempsavegame
```

and then promotes the completed temporary save to the real `savegameN` directory.

For that reason, the marker is **not** written during mission loading. It is written from the `FSBaseMission.saveSavegame` hook, where `missionInfo.savegameDirectory` points to `tempsavegame`.

A typical log can therefore contain a temporary path during the save operation, while the finished file correctly appears afterwards in:

```text
savegame1/newCareerDefaults.xml
```

The marker contains only a few informational attributes. Its existence is what matters.

## Lifecycle hooks

The mod uses three small FS25 lifecycle hooks:

| Hook | Purpose |
| --- | --- |
| `Mission00.loadMission00Finished` | Detect a standard new career and initialize its calendar |
| `FSBaseMission.saveSavegame` | Write the marker as part of the normal save operation |
| `FSBaseMission.delete` | Clear transient state when leaving a career |

The transient marker flag is also reset at the beginning of every mission load. This prevents an unsaved new career from leaking pending state into another savegame opened in the same FS25 session.

## Files

```text
FS25_NewCareerDefaults/
├── scripts/
|   └── NewCareerDefaults.lua
├── modDesc.xml
├── README.md
└── README.pl.md
```

The ZIP package must contain these files directly at its root.

## Installation

1. Copy `FS25_NewCareerDefaults.zip` to the Farming Simulator 25 `mods` directory.
2. Start Farming Simulator 25.
3. Create a **new career**.
4. Enable **New Career Defaults** for that career.
5. Enter the game.
6. Open the game settings and verify that **Days per month = 3**.
7. Verify that the HUD still shows the **first day of August**.
8. Save the career once.

After saving, `newCareerDefaults.xml` should be present in the corresponding `savegameN` directory.

## Expected log entries

A successful first initialization produces a concise message similar to:

```text
Info: [FS25_NewCareerDefaults] New career initialized: 3 days/month, starting on August 1.
```

After the first normal save:

```text
Info: [FS25_NewCareerDefaults] Initialization marker saved.
```

Warnings are written only when an expected FS25 API or save path is unavailable.

## Configuration

The default value is defined near the top of `NewCareerDefaults.lua`:

```lua
local DEFAULT_DAYS_PER_PERIOD = 3
```

The `currentDay` conversion and `timeAdjustment` value are calculated automatically from this number.

If the value is changed, it is also recommended to update the human-readable descriptions in `modDesc.xml` and the README files.

## Existing savegames

The mod is designed for a new career and does not intentionally migrate arbitrary existing saves.

A save with `newCareerDefaults.xml` is always left alone.

The final detection also requires the vanilla starting `currentMonotonicDay = 6`, which prevents normal older careers from being mistaken for a new one.

There is one recovery path: if a save has exactly the initial calendar state already produced by an earlier version of this mod but is missing the marker, the calendar is not changed again; the marker is simply recreated during the next save.

## Removing the mod

Once the first save has been made, FS25 itself stores the selected `plannedDaysPerPeriod` value. Removing the mod does not require converting the save back to one day per month.

The `newCareerDefaults.xml` marker is harmless without the mod. It can be left in the savegame or deleted manually after the mod has been permanently removed.

## Compatibility notes

- Farming Simulator 25
- PC script mod
- single-player intended
- no vehicle specializations required
- no map-specific code
- no dependency on `environment.currentMonth`
- does not modify `currentMonotonicDay`

## Change history

### 1.0.0.4 — Final

- Cleaned and reorganized the source code.
- Added extensive comments documenting the FS25 calendar model and lifecycle choices.
- Added `currentMonotonicDay = 6` to the standard-new-career signature to reduce false positives.
- Reset the transient `markerPending` flag on every mission load.
- Added a mission-delete reset so an unsaved career cannot leave pending state for another save in the same game session.
- Reduced diagnostic logging to concise production messages and warnings.
- Added complete English and Polish documentation.

### 1.0.0.3 — Marker persistence fix

- Moved marker creation from mission loading to `FSBaseMission.saveSavegame`.
- Correctly allowed the marker to be created in `tempsavegame` and transferred by FS25 to the final `savegameN`.
- Added recovery for saves already initialized by an earlier test build but missing the marker.
- Verified in-game that the marker appears in the final savegame directory.

### 1.0.0.2 — Calendar detection fix

- Removed `environment.currentMonth` from new-career detection after testing showed it is `nil` in `Mission00.loadMission00Finished`.
- Used `currentPeriod = 6` and the other initialized calendar fields instead.
- Verified in-game:
  - `3` days per month in settings;
  - HUD remains on August 1;
  - `currentDay = 16`;
  - `timeAdjustment = 1/3`;
  - `currentMonotonicDay` remains unchanged.

### 1.0.0.1 — Lifecycle diagnostic build

- Replaced the initial event-listener approach with a direct `Mission00.loadMission00Finished` hook.
- Added detailed diagnostic logging to expose the actual initial FS25 calendar state.

### 1.0.0.0 — Initial prototype

- First implementation of automatic 3-day-per-month initialization for a new FS25 career.
- Initial marker and calendar-conversion concept.
