# FS25_NewCareerDefaults

Small script mod for Farming Simulator 25 that changes the default calendar of a newly created standard career.

## Default behavior

- standard FS25 start: **1 August**
- days per month: **3**
- the change takes effect immediately, without waiting for the next season
- existing/non-standard careers are not modified
- a marker file is written to the savegame so the initialization is not applied twice
- `currentMonotonicDay` is deliberately left untouched

For the standard FS25 calendar August is period 6. With 3 days per period, the first day of August is represented internally as:

`currentDay = (6 - 1) * 3 + 1 = 16`

## Configuration

Edit this constant in `NewCareerDefaults.lua`:

```lua
local DEFAULT_DAYS_PER_PERIOD = 3
```

The target `currentDay` is calculated automatically.

## Expected log entry

After starting a new career with the mod enabled:

```text
Info: [FS25_NewCareerDefaults] Applied new career defaults: 3 days/month, August day 1 (currentDay=16).
```

On later loads:

```text
Info: [FS25_NewCareerDefaults] Defaults were already applied to this savegame; no changes made.
```

## Testing

1. Copy `FS25_NewCareerDefaults.zip` to the FS25 `mods` directory.
2. Create a completely new career.
3. Enable the mod for that career.
4. Enter the game.
5. Check the game settings: days per month should be `3`.
6. Save and reload the career.
7. Confirm that it still starts/continues normally and the mod does not reinitialize the calendar.

The mod is intended for single-player use.
