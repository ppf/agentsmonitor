# Build Verification Checklist

## Files Created ✅
1. AppTheme.swift - Theme constants, colors, font sizes
2. StatusBadge.swift - Status badge component
3. Models.swift - Message, ToolCall, MessageRole, ToolCallStatus
4. NewSessionSheet.swift - New session creation sheet
5. MetricsView.swift - Metrics display view
6. MenuBarView.swift - Menu bar extra view
7. TerminalThemes.swift - Terminal theming system
8. AgentProcessManager.swift - Process lifecycle manager
9. SessionDebugView.swift - Debug view for troubleshooting
10. BUILD_FIXES.md - Initial build fixes documentation
11. SESSION_LOADING_FIX.md - Session loading fixes documentation

## Files Modified ✅
1. Session.swift - Enhanced SessionMetrics with cache fields
2. SessionStore.swift - Improved loading logic, added working directory detection
3. AgentsMonitorApp.swift - Added debug window
4. AppTheme.swift - Added FontSize enum
5. SettingsView.swift - Added TerminalSettingsView
6. Models.swift - Added formattedTime and toolIcon to ToolCall

## Known Issue ⚠️
**Duplicate SessionMetrics Definition**
- File: `/repo/SessionMetrics.swift`
- **Action Required**: Delete this file
- The correct version is in `Session.swift`

## Compilation Check

### Import Dependencies
- ✅ SwiftUI
- ✅ SwiftTerm  
- ✅ AppKit
- ✅ Foundation
- ✅ Darwin
- ✅ os.log
- ✅ UniformTypeIdentifiers

### Type Dependencies

#### AppTheme
- ✅ Defines: CornerRadius, Spacing, statusColors, toolCallStatusColors, FontSize
- ✅ Used in: ContentView, StatusBadge, ToolCallsView, MetricsView, SettingsView

#### Session Models
- ✅ Session struct (Session.swift)
- ✅ SessionSummary struct (Session.swift)
- ✅ SessionStatus enum (Session.swift)
- ✅ SessionMetrics struct (Session.swift) - **Delete duplicate!**
- ✅ AgentType enum (Session.swift)

#### Message Models  
- ✅ Message struct (Models.swift)
- ✅ MessageRole enum (Models.swift)
- ✅ ToolCall struct (Models.swift)
- ✅ ToolCallStatus enum (Models.swift)

#### Views
- ✅ ContentView
- ✅ SessionListView
- ✅ SessionDetailView
- ✅ TerminalContainerView
- ✅ ToolCallsView
- ✅ MetricsView
- ✅ StatusBadge
- ✅ NewSessionSheet
- ✅ MenuBarView
- ✅ SettingsView (all sub-views present)
- ✅ SessionDebugView

#### State Management
- ✅ SessionStore (Observable class)
- ✅ AppState (Observable class)
- ✅ SessionPersistence (actor)
- ✅ AgentProcessManager (actor)

#### Services
- ✅ AgentService (actor)
- ✅ AgentProcessDiscovery (class)
- ✅ TerminalBridge (class)

#### Utilities
- ✅ AppLogger (final class)
- ✅ TerminalThemes (enum)

### Cross-File References Check

#### ContentView.swift
- ✅ Uses: SessionStore, AppState, SessionListView, SessionDetailView
- ✅ Uses: AppTheme.CornerRadius, AppTheme.statusColors
- ✅ Uses: SessionStatus, LoadingOverlay, EmptyStateView, FilterMenu

#### SessionListView.swift
- ✅ Uses: SessionStore, AppState, StatusBadge, NewSessionSheet
- ✅ Uses: Session, SessionRowView, SessionContextMenu

#### SessionDetailView.swift
- ✅ Uses: Session, AppState, SessionStore, StatusBadge
- ✅ Uses: TerminalContainerView, ToolCallsView, MetricsView
- ✅ Uses: QuickMetricsView, MetricItem, SessionActionButtons

#### TerminalView.swift
- ✅ Uses: Session, SessionStore, TerminalThemes, TerminalThemeSelection
- ✅ Uses: TerminalBridge, SwiftTerm.TerminalView

#### ToolCallsView.swift
- ✅ Uses: ToolCall, AppTheme, ToolCallStatus
- ✅ Uses: Environment codeFontSize

#### MetricsView.swift
- ✅ Uses: SessionMetrics, Session, AppTheme

#### SettingsView.swift
- ✅ Uses: AgentType, AppTheme.FontSize, TerminalThemeSelection
- ✅ Uses: SessionPersistence, AppLogger

#### SessionStore.swift
- ✅ Uses: Session, SessionSummary, Message, ToolCall
- ✅ Uses: AgentService, SessionPersistence, AgentProcessManager
- ✅ Uses: TerminalBridge, AppLogger

#### SessionPersistence.swift
- ✅ Uses: Session, SessionSummary, Message, ToolCall
- ✅ Uses: SessionMetrics (from Session.swift)

## Build Steps

1. **Delete Duplicate File**
   ```bash
   rm /repo/SessionMetrics.swift
   ```

2. **Build in Xcode**
   ```bash
   # Press Cmd+B in Xcode
   # OR from command line:
   xcodebuild -scheme AgentsMonitor -configuration Debug
   ```

3. **Run Tests**
   ```bash
   # Press Cmd+U in Xcode
   # OR from command line:
   xcodebuild test -scheme AgentsMonitor
   ```

4. **Run the App**
   ```bash
   # Press Cmd+R in Xcode
   ```

## Expected Results

### On First Launch
- ✅ No saved sessions found (empty directory)
- ✅ Detects running agent processes (if any)
- ✅ Shows detected processes with actual working directories
- ✅ If no processes, shows demo mock data

### Debug View (Cmd+Shift+D)
- ✅ Shows session counts (external vs persisted)
- ✅ Shows persistence directory path
- ✅ Shows file count (should be 0 on first launch)
- ✅ Buttons to open directory and clear sessions

### Creating a Session
- ✅ New Session button works
- ✅ Can set name, agent type, working directory
- ✅ Session appears in sidebar
- ✅ Session is saved to disk

### After Restart
- ✅ Previously created sessions load from disk
- ✅ Running agents still detected
- ✅ Both types appear in session list

## Potential Issues & Solutions

### Issue: Duplicate Symbol Error
**Symptom**: `duplicate symbol '_$s13AgentsMonitor14SessionMetricsV...'`
**Solution**: Delete `/repo/SessionMetrics.swift`

### Issue: Cannot find 'TerminalSettingsView'
**Symptom**: Use of unresolved identifier 'TerminalSettingsView'
**Solution**: Already fixed in SettingsView.swift

### Issue: Cannot find type 'FontSize' in 'AppTheme'
**Symptom**: Type 'AppTheme' has no member 'FontSize'
**Solution**: Already fixed in AppTheme.swift

### Issue: Working directories all show /users/storm
**Symptom**: All sessions show same directory
**Solution**: Fixed with lsof-based detection in SessionStore.swift

### Issue: No historical sessions loading
**Symptom**: Only seeing detected processes
**Solution**: Check Debug View for persistence directory and file count

## Final Checklist

- [ ] Delete `/repo/SessionMetrics.swift`
- [ ] Build succeeds (Cmd+B)
- [ ] No compiler errors
- [ ] No compiler warnings (or acceptable warnings only)
- [ ] App launches successfully
- [ ] Debug view opens (Cmd+Shift+D)
- [ ] Can create new session
- [ ] Session appears in sidebar
- [ ] Session persists after restart

---

**Status**: Ready to build after deleting duplicate SessionMetrics.swift
