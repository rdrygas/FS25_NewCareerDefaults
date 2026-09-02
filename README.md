# FS25_NewCareerDefaults

Version 1.0.0.2

Sets a standard brand-new Farming Simulator 25 career to:

- 3 days per month
- first day of August

## Detection

The mod recognizes the standard FS25 starting state using:

- `currentPeriod = 6` (August)
- `currentDay = 6`
- `currentDayInPeriod = 1`
- `daysPerPeriod = 1`
- `plannedDaysPerPeriod = 1` (or nil)

`environment.currentMonth` is deliberately not used because it can still be `nil`
when `Mission00.loadMission00Finished` is called.

## Applied state

For 3 days per period, August period 6 starts at:

`currentDay = (6 - 1) * 3 + 1 = 16`

The mod also sets:

- `daysPerPeriod = 3`
- `plannedDaysPerPeriod = 3`
- `timeAdjustment = 1 / 3`

`currentMonotonicDay` is deliberately left unchanged.

## Expected log

```text
Info: [FS25_NewCareerDefaults] Script loaded.
Info: [FS25_NewCareerDefaults] Hook installed: Mission00.loadMission00Finished.
Info: [FS25_NewCareerDefaults] Mission00.loadMission00Finished called.
Info: [FS25_NewCareerDefaults] Calendar before check: ...
Info: [FS25_NewCareerDefaults] Called FSBaseMission:setPlannedDaysPerPeriod(3).
Info: [FS25_NewCareerDefaults] Applied: ...
```
