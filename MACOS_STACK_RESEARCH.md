# macOS Native App Development Stack Research (2025-2026)

## Executive Summary

For building an agent monitoring app (like Conductor or Codex Monitor) on macOS with **speed as the top priority** and **native feel as secondary**, here are the research findings:

| Framework | Dev Speed | Runtime Perf | Native Feel | Best For |
|-----------|-----------|--------------|-------------|----------|
| **SwiftUI + Swift** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Most apps, rapid prototyping |
| **AppKit + Swift** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Performance-critical apps |
| **Tauri (Rust + Web)** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | Small binaries, web dev teams |
| **Dioxus (Pure Rust)** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | Rust-first teams |

---

## 1. SwiftUI + Swift (Apple Native)

### Runtime Performance
- **List performance**: macOS 26 brought 10x improvement - 10,000 items feel snappy; 50,000 usable
- **General UI**: 5-10% slower than AppKit in benchmarks, but "fast enough" for 95% of use cases
- **List scrolling**: 58 FPS vs AppKit's 60 FPS (imperceptible difference)
- **Memory**: Uses ~13% more than AppKit
- **App launch**: ~10% slower than AppKit
- **Text rendering**: Can cause hitching with large amounts of text (ChatGPT-style apps) - bridge NSTextView for performance

### Development Speed
- **3x faster development** than AppKit/UIKit with declarative code
- Live previews in Xcode - see changes instantly without rebuilding
- Significantly less boilerplate code
- Hot reload capabilities
- Single codebase works across iOS, macOS, watchOS, tvOS

### Native macOS Integration
- **Excellent** - First-party Apple framework
- Automatic adaptation to system appearance, Dark Mode, accessibility
- Native system integrations (menu bar, notifications, widgets)
- Liquid Glass material support in macOS 26
- Full access to all Apple APIs

### Pros
- Fastest development cycle
- Apple's recommended future direction
- Excellent documentation and WWDC resources
- Growing ecosystem and community (70% of new apps in 2025)
- Can interop with AppKit when needed (NSViewRepresentable)
- SwiftUI Instruments template for performance debugging

### Cons
- Still maturing (5.5 years old)
- Less control than AppKit for complex scenarios
- Performance issues with very complex state management (see Browser Company case)
- Text rendering needs AppKit bridge for streaming scenarios
- Some StackOverflow answers outdated

### Notable Apps Built With SwiftUI
- **CodeEdit** - Open-source code editor for macOS
- **Cork** - Fast GUI for Homebrew
- **Swiftcord** - Native Discord client
- **VirtualBuddy** - macOS virtualization
- **NotchDrop** - Dynamic Island-style notch utility
- **isowords** - Award-winning game
- **HuggingChat** - Native chat for LLMs

### Recommendation for Agent Monitoring
SwiftUI is ideal for most UI components. For the streaming text output (AI responses), bridge NSTextView for optimal performance. Use SwiftUI's new Instruments template to debug any performance issues.

---

## 2. AppKit + Swift

### Runtime Performance
- **Best possible** - Native framework, highly optimized
- Essential for **sub-16ms frame time requirements** (browsers, games, creative tools)
- Lower memory footprint than SwiftUI
- Faster app launch times
- Required for extreme performance scenarios

### Development Speed
- **Slower than SwiftUI** - More manual layout code required
- Explicit positioning and sizing vs SwiftUI's automatic layout
- More boilerplate code
- Mature, stable APIs - fewer surprises
- Better StackOverflow coverage for edge cases

### Native macOS Integration
- **Perfect** - It IS the native macOS framework
- Powers Finder, Safari, TextEdit, Preview, Calendar
- Full control over every aspect of the UI
- Best window management and application lifecycle control
- New Liquid Glass support in macOS 26

### Pros
- Maximum runtime performance
- Full control over app behavior
- Battle-tested over 20+ years
- Best for complex navigation, text editing, high-performance lists
- Essential for apps requiring <16ms frame times

### Cons
- Significantly slower development time
- More verbose code
- Steeper learning curve
- Not Apple's future direction (though still fully supported)
- No cross-platform benefits

### Notable Apps Built With AppKit
- **Finder, Safari, TextEdit, Preview** (Apple's own apps)
- **Arc Browser** (partially, moving Dia fully to AppKit)
- **Sublime Text**
- **Dependencies** (dSYM analyzer)
- Most professional macOS apps

### The Browser Company Case Study
Arc browser switched from SwiftUI to AppKit for their new Dia browser due to:
- Latency issues
- UI hitching
- CPU overhead
- Need for sub-16ms frame times

However, community analysis suggested their issues stemmed partly from using an outdated TCA (The Composable Architecture) fork and improper state management, not purely SwiftUI limitations.

---

## 3. Tauri (Rust Backend + Web Frontend)

### Runtime Performance
- **Startup**: Under 500ms (50% faster than Electron)
- **Binary size**: 2.5-3 MB (vs Electron's 80-120 MB)
- **RAM usage**: 30-40 MB idle (1/3 of Electron)
- **IPC performance**: ~5ms on macOS for 10MB data
- Uses native WebView (WKWebView on macOS) - no bundled Chromium

### Development Speed
- **Good** - Leverages existing web development skills
- Use any web framework (React, Vue, Svelte, Solid)
- Rust backend for performance-critical logic
- Hot reload for frontend
- 35% adoption increase year-over-year after Tauri 2.0

### Native macOS Integration
- **Good but not perfect** - Uses system WebView
- Native window controls and menu bar
- Access to `NSWindow` content view via `tauri::WebviewWindow::ns_view`
- Minor CSS/font rendering differences from native
- Can feel "web-ish" compared to pure native

### Pros
- Tiny binaries and low memory footprint
- Rust backend for security and performance
- Leverage existing web skills and libraries
- Growing ecosystem of plugins
- Cross-platform if needed later
- Security-first design

### Cons
- Not truly native UI - WebView-based
- WebKit rendering differences on macOS
- Requires learning Rust for backend
- Harder to achieve AppKit-level polish
- Some native macOS features require more work

### Notable Apps Built With Tauri
- **ChatGPT Desktop** - OpenAI's official app
- **Jan** - Open-source offline LLM client
- **Yaak** - REST/GraphQL/gRPC client
- **SilentKeys** - Privacy-first dictation
- **Ariadne** - Git client (praised for performance)
- **Browsernaut** - macOS browser picker

### Recommendation for Agent Monitoring
Good choice if your team has web development expertise and wants small binaries. The streaming text performance would be handled by the web frontend, which is mature for this use case.

---

## 4. Dioxus (Pure Rust)

### Runtime Performance
- **Hello world**: ~50kb binary
- Reactive updates (Solid.js-style) - efficient DOM diffs
- Can beat Tauri in benchmarks for UI-heavy apps
- Experimental native rendering via WGPU/Freya (Skia)
- Rust's memory safety guarantees

### Development Speed
- **Moderate** - RSX syntax (JSX-like) is approachable
- Hot reloading support
- Tailwind CSS integration
- Integrated debugger
- Younger framework = fewer resources/examples

### Native macOS Integration
- **Limited** - Still relies on WebView for rendering
- Experimental native rendering not production-ready
- Not AppKit-level polish
- Can write macOS-specific Rust code naturally

### Pros
- Pure Rust codebase (no JavaScript)
- Signals-based state management
- Very small binaries
- Improving rapidly (v0.7 added Tailwind, Radix UI)
- Full Rust ecosystem access

### Cons
- Younger than Tauri - fewer battle scars
- Still WebView-based (mostly)
- Smaller community
- Fewer production examples
- Native rendering still experimental

### Notable Apps
- Fewer high-profile production apps than Tauri
- Growing adoption in educational and internal tools

---

## 5. Other Options Considered

### Electron
- **Not recommended** for macOS-only apps
- Large binary sizes (80-120MB)
- High memory usage
- Slower startup
- Only choose if you need extensive cross-platform + web code sharing

### Flutter
- Good for cross-platform (iOS/Android primary)
- macOS support is secondary
- Not native feel on macOS
- Better suited for mobile-first apps

### .NET MAUI
- Good for Microsoft ecosystem teams
- Native performance on macOS
- C#/XAML if that's your team's expertise
- Less common for macOS-primary development

---

## Recommendation for Agent Monitoring App

### Primary Recommendation: **SwiftUI + Swift with AppKit Bridges**

Given your priorities:
1. **Speed** (development + runtime) - Most important
2. **Native macOS feel** - Secondary
3. **macOS only** - No cross-platform needed

**SwiftUI is the optimal choice** because:

1. **Fastest development cycle** - 3x faster than AppKit, live previews
2. **Excellent native feel** - First-party Apple framework, automatic system integration
3. **Good enough performance** - For a monitoring app (not a browser), SwiftUI is performant
4. **macOS 26 improvements** - Lists now handle 10,000+ items smoothly
5. **Easy escape hatches** - Bridge AppKit components when needed

**Architecture Recommendations:**
```
┌─────────────────────────────────────────────┐
│            Main UI: SwiftUI                 │
│  - Session list/grid                        │
│  - Toolbar & navigation                     │
│  - Settings & preferences                   │
│  - Git integration UI                       │
├─────────────────────────────────────────────┤
│     Performance-Critical: AppKit Bridge     │
│  - NSTextView for streaming AI output       │
│  - Core Text for heavy text rendering       │
│  - Custom NSView for real-time graphs       │
└─────────────────────────────────────────────┘
```

**Key Implementation Tips:**
- Use `NSViewRepresentable` to wrap NSTextView for streaming text output
- Leverage SwiftUI Instruments template for performance debugging
- Use `@Observable` (Swift 5.9+) for modern state management
- Consider avoiding TCA for performance-critical paths (per Browser Company learnings)

### Alternative: **Tauri** (if Rust expertise exists)

Choose Tauri if:
- Your team has strong web development skills
- You want very small binary sizes (<10MB)
- Low memory usage is critical
- You're comfortable with Rust
- Cross-platform might be needed later

---

## Sources

### SwiftUI & AppKit
- [SwiftUI for Mac 2025 - TrozWare](https://troz.net/post/2025/swiftui-mac-2025/)
- [State of Swift 2026](https://devnewsletter.com/p/state-of-swift-2026)
- [SwiftUI 2025: What's Fixed, What's Not](https://juniperphoton.substack.com/p/swiftui-2025-whats-fixed-whats-not)
- [AppKit to SwiftUI Migration Experience](https://blog.smittytone.net/2025/03/25/macos-development-appkit-swift-ui/)
- [Arc, Dia, TCA and SwiftUI Analysis](https://fatbobman.com/en/weekly/issue-086/)
- [SwiftUI vs UIKit 2025](https://www.alimertgulec.com/en/blog/swiftui-vs-uikit-2025)
- [Apple AppKit Documentation](https://developer.apple.com/documentation/appkit)

### Tauri
- [Tauri 2.0 Stable Release](https://v2.tauri.app/blog/tauri-20/)
- [Tauri vs Electron 2025 Comparison](https://www.raftlabs.com/blog/tauri-vs-electron-pros-cons/)
- [Tauri vs Electron Performance Analysis](https://www.gethopp.app/blog/tauri-vs-electron)
- [Awesome Tauri Apps](https://github.com/tauri-apps/awesome-tauri)

### Dioxus
- [Dioxus GitHub](https://github.com/DioxusLabs/dioxus)
- [Tauri vs Dioxus Comparison](https://medium.com/solo-devs/tauri-vs-dioxus-the-ultimate-rust-showdown-5d8d305497d6)
- [Rust Cross-Platform Development 2025](https://medium.com/@vignarajj/rusts-cross-platform-frontier-guiding-mobile-devs-through-tauri-and-dioxus-in-2025-538917385064)

### Agent Monitoring Tools
- [Conductor Official Site](https://www.conductor.build/)
- [Conductor Hands-On Review - The New Stack](https://thenewstack.io/a-hands-on-review-of-conductor-an-ai-parallel-runner-app/)

### General
- [Awesome Swift macOS Apps](https://github.com/jaywcjlove/awesome-swift-macos-apps)
- [SwiftUI macOS Resources](https://github.com/stakes/swiftui-macos-resources)
- [Best Desktop Frameworks 2026](https://tibicle.com/blog/best-framework-for-desktop-application-in-2026)
