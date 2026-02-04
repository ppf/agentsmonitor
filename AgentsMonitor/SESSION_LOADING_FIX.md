# Session Loading Issue - Fixed

## Problem Description

All sessions were showing as being in `/users/storm` directory, and there was no session history. Every session clicked appeared as a new session in that directory.

## Root Causes Identified

### 1. **External Process Detection Without Working Directory**
- The `detectRunningAgents()` function was detecting running agent processes via `ps` command
- These detected processes were created with `workingDirectory: nil`
- When a session starts without a working directory, it defaults to the user's home directory

### 2. **No Historical Session Data**
- Either no sessions have been saved yet, OR
- The persistence directory is empty/new installation

### 3. **Mock Data Loading**
- The app was potentially loading mock data when no persisted sessions were found
- Mock sessions all had working directories set to the home directory

## Fixes Applied

### 1. **Enhanced Process Detection with Working Directory** ✅
Added `getWorkingDirectory(for:)` function that uses `lsof` to find the actual working directory of detected processes:

```swift
private func getWorkingDirectory(for pid: Int32) -> URL? {
    // Uses lsof -a -p PID -d cwd to get current working directory
    // Returns the actual directory where the agent process is running
}
```

### 2. **Improved Session Loading Logic** ✅
Updated `loadPersistedSessions()` to:
- First check for persisted sessions
- Then detect running agents
- Only load mock data if BOTH are empty
- Added detailed logging to track what's happening

### 3. **Better Session Naming** ✅
Changed detected external process naming from:
```swift
"\(agentType.displayName) (Detected \(pid))"
```
to:
```swift
"\(agentType.displayName) - PID \(pid)"
```
This makes it clearer these are detected processes.

### 4. **Added Debug View** ✅
Created `SessionDebugView` accessible via:
- Menu: **Sessions → Debug Info...**
- Keyboard: **Cmd+Shift+D**

This shows:
- Total sessions count
- External vs persisted sessions breakdown
- Working directory for each session
- Persistence storage location and file count
- Actions to open storage directory or clear all saved sessions

## How to Diagnose the Issue

1. **Open the Debug View**:
   - Press `Cmd+Shift+D` or go to **Sessions → Debug Info...**

2. **Check the information shown**:
   - **Current Sessions**: See how many are external vs persisted
   - **Persistence Storage**: See where sessions are saved and how many files exist

3. **Verify Session Details**:
   - Look at each session's working directory
   - External processes should now show their actual working directory (if detectable)

## Expected Behavior

### First Launch (No History)
- App detects any running agent processes
- Gets their actual working directories via `lsof`
- Shows these as "External" sessions with bolt icon
- If no external processes found, shows mock data for demo purposes

### With Saved History
- Loads all previously saved sessions from disk
- ALSO detects any new running agent processes
- Combines both in the session list
- External processes appear at the top with bolt icon

### When Clicking a Session
- **External processes**: Shows read-only view (can't control them directly)
- **App-managed sessions**: Full control (terminal, pause, resume, etc.)
- Working directory should reflect the actual directory

## Troubleshooting

### Still Seeing `/users/storm` for Everything?

1. **Check if processes are actually running there**:
   ```bash
   lsof -a -p <PID> -d cwd -Fn
   ```

2. **The `lsof` command might need permissions**:
   - Grant Full Disk Access to the app in System Settings
   - Or the processes might actually be running in that directory

### No History Loading?

1. **Check storage location**:
   - Open Debug View (Cmd+Shift+D)
   - Look at "Persistence Storage" section
   - Click "Open Storage Directory" button

2. **Check Console logs**:
   - Open Console.app
   - Filter for "AgentsMonitor" or "persistence"
   - Look for errors

### Want Fresh Start?

1. Open Debug View (Cmd+Shift+D)
2. Click "Clear All Saved Sessions"
3. Restart the app

## Testing the Fix

1. **Run the app**
2. **Open Debug View** (Cmd+Shift+D)
3. **Check**:
   - Are external processes detected?
   - Do they show working directories?
   - Is persistence directory created?
   - Are sessions being saved?

4. **Create a new session**:
   - Use "New Session" button
   - Set a specific working directory
   - Start it
   - Check if it appears in debug view

5. **Restart the app**:
   - Close and reopen
   - Previously created sessions should load from disk
   - Running agents should still be detected

## Additional Notes

- **External processes** are detected from `ps` output
- **Working directory detection** uses `lsof` (requires permissions)
- **Session persistence** saves to `~/Library/Application Support/AgentsMonitor/Sessions/`
- **Mock data** only loads if no real sessions exist (saved or running)

## Next Steps

After applying these fixes:

1. Build and run the app
2. Open the Debug View to see what's happening
3. Check the Console.app logs for detailed persistence messages
4. Verify that new sessions save their working directory correctly
5. Test that restarting the app loads saved sessions

---

**Key Improvement**: The app now accurately detects and displays the working directory of running agent processes, and clearly distinguishes between app-managed sessions and externally detected processes.
