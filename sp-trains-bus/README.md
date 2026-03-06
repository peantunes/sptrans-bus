# Due SP (sp-trains-bus)

iOS app for Sao Paulo transit, including bus arrivals, rail status, maps, widgets, and watch support.

## App Intents (Siri + Shortcuts)

The app currently exposes these intents:

1. `GetNextArrivalsIntent`
   - Purpose: Get next arrivals for a selected stop.
   - Parameters: `Stop`, optional `Limit` (1...20).
2. `CheckRailStatusIntent`
   - Purpose: Check Metro/CPTM network status, or a specific line.
   - Parameters: optional `Rail Line`.
3. `OpenStopIntent`
   - Purpose: Open a stop directly inside the app.
   - Parameters: `Stop`.

### Siri phrases

You can use these phrases (or close variations):

1. "Check arrivals at <stop> in Due SP"
2. "When is the next bus at <stop> in Due SP"
3. "Check rail status in Due SP"
4. "How are Metro and CPTM now in Due SP"
5. "Open stop <stop> in Due SP"
6. "Show stop <stop> in Due SP"

## How to access via Siri

1. Launch Due SP at least once after install/update (registers App Shortcuts metadata).
2. Open iOS `Shortcuts` app.
3. Tap `+`, then `Add Action`, search for `Due SP`.
4. Pick one of the actions above and configure parameters (for example, stop and limit).
5. (Optional) Rename the shortcut to your preferred voice phrase.
6. Invoke with `Hey Siri, <your phrase>`.

## Notes

1. Stop-based intents require selecting a valid stop entity.
2. Rail status intent works with or without line selection.
3. More intents are planned in `AppIntents_Future_Implementations_Report.md`.
