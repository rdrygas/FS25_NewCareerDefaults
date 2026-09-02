# FS25_NewCareerDefaults

Version 1.0.0.3

Sets a standard brand-new Farming Simulator 25 career to:

- 3 days per month
- first day of August

## Persistence marker

The marker file is:

`newCareerDefaults.xml`

It is no longer created during mission loading. Instead, the mod waits until the
game finishes its normal save operation and then writes the marker to the savegame
directory.

This avoids the marker being lost while a new career savegame directory is being
created/replaced by Farming Simulator.

The mod also recognizes the initial state already produced by v1.0.0.2
(3 days/month, August day 1, `currentDay=16`) and will create a missing marker on
the next save without changing the calendar again.

## Expected log after a save

```text
Info: [FS25_NewCareerDefaults] Marker saved: .../savegameX/newCareerDefaults.xml
```
