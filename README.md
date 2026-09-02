# FS25_NewCareerDefaults

Diagnostic/fixed build 1.0.0.1.

The mod sets a standard brand-new Farming Simulator 25 career to:

- 3 days per month
- first day of August

This build hooks `Mission00.loadMission00Finished` directly and writes detailed
calendar information to `log.txt`.

Expected early log entries:

```text
Info: [FS25_NewCareerDefaults] Script loaded.
Info: [FS25_NewCareerDefaults] Hook installed: Mission00.loadMission00Finished.
```

When entering a career:

```text
Info: [FS25_NewCareerDefaults] Mission00.loadMission00Finished called.
Info: [FS25_NewCareerDefaults] Calendar before check: ...
```

For a standard new career it should then print an `Applied:` line.

`currentMonotonicDay` is intentionally not changed.
