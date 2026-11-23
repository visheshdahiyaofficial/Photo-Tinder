<p align="center">
  <img src="Photo%20Tinder/Assets.xcassets/AppIcon.appiconset/Photo%20Tinder-iOS-Default-1024@1x.png" width="140" alt="Photo Tinder app icon" />
</p>

<h1 align="center">Photo Tinder</h1>

<p align="center">
  <b>Swipe through your camera roll, oldest photo first, and finally clean it up.</b><br/>
  Right to keep · Left to delete · Up to favorite
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2018%2B-blue" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-orange" />
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-pink" />
  <img alt="Storage" src="https://img.shields.io/badge/persistence-SwiftData-green" />
  <img alt="Dependencies" src="https://img.shields.io/badge/dependencies-none-lightgrey" />
</p>

---

## Table of contents

- [What is Photo Tinder?](#what-is-photo-tinder)
- [Features](#features)
- [How it works (user flow)](#how-it-works-user-flow)
- [Gestures and controls](#gestures-and-controls)
- [Safety: how deletion works](#safety-how-deletion-works)
- [Gamification](#gamification)
- [Settings](#settings)
- [Privacy](#privacy)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Project structure](#project-structure)
- [Architecture overview](#architecture-overview)
- [Tech stack](#tech-stack)
- [Known limitations](#known-limitations)
- [Roadmap ideas](#roadmap-ideas)
- [Contributing](#contributing)

---

## What is Photo Tinder?

Most people have thousands of photos they will never look at again: blurry
shots, duplicates, screenshots of things that no longer matter, ten takes of
the same sunset. Going through them in the Photos app is slow and boring, so
nobody does it.

**Photo Tinder turns cleaning your library into a quick swipe game.** It
shows your library one card at a time, **starting with the oldest item**, and
you decide each one with a flick:

| Swipe | Meaning | What happens |
|-------|---------|--------------|
| ➡️ Right | **Keep** | Marked as reviewed and never shown again (unless you start over). |
| ⬅️ Left | **Delete** | Goes to a **delete pile**. Nothing leaves your library until you confirm. |
| ⬆️ Up | **Favorite** | Kept *and* marked as a Favorite in the iOS Photos app. |

The app remembers every decision, so you can close it at any time and pick up
exactly where you left off, even across thousands of photos and many days.

Everything runs **on your device**. There is no account, no server, no
analytics, and no third-party code.

---

## Features

### 🃏 The swipe deck
- **Oldest first.** The deck walks your library in creation-date order, so you
  travel through your own history. The header shows the month and year you're
  currently in (for example *"March 2017"*).
- **Photos, Live Photos, videos and screenshots** are all supported. Each card
  shows badges for *Video* (with duration), *Live*, *Screenshot* and the item's
  **file size**, plus a heart if it's already a Favorite.
- **Videos auto-play muted and loop** on the top card, with a tap-to-unmute button.
- **Physics-style card stack.** The next two cards peek out behind the top one,
  and cards tilt as you drag them.
- **Flick detection.** A fast flick counts as a swipe even if your finger
  didn't travel far, because the app uses the gesture's predicted end point.
- **Button controls** for one-handed use: Undo, Delete, Favorite and Keep.
- **Up to 50 levels of undo.** Undo also reverses a favorite you just added.
- **Press and hold** a card to open it **full screen**: pinch or double-tap to
  zoom up to 5×, drag to pan, swipe down to close. Videos play with full controls.
- **Progress bar** with "*N left · X% reviewed*".
- **Instant swipes.** The next cards are prefetched into PhotoKit's image cache
  ahead of time, and a quick low-res image is shown first while the full-quality
  version (even from iCloud) loads.

### ✨ Swipe feedback
- A full-screen **animated overlay** builds up as you drag: a big thumbs-up
  (green), thumbs-down (red) or star (orange) surrounded by a ring of smaller
  icons that spread out, sway and glow.
- When the swipe lands the icons **pop, then fade and drift away**. Each swipe
  gets a freshly randomized layout so it never looks repetitive.
- **Haptics**: a tick as you cross the swipe threshold, a thud for delete, a
  success tap for keep/favorite, and a light tap on long-press.
- Respects **Reduce Motion**: the sway and drift are turned off.

### 🗑️ The delete pile
- A grid of everything you swiped left, newest decision first, with a **badge
  count** on the tab bar.
- Shows the **total size** you're about to free, e.g. *"Delete 248 items · 1.3 GB"*.
- **Rescue** any item with one tap (or long-press → *Keep instead*).
- **"Keep all and return to deck"** empties the pile without deleting anything.
- **One tap, one system prompt.** All pending items are deleted in a single
  PhotoKit change request, so iOS asks for permission once, not once per photo.

### 📊 Stats & achievements
- A ring showing how much of the library you've reviewed and which month you've reached.
- Tiles for **Kept**, **Deleted**, **In pile**, **Space freed**, **Current
  streak**, **Best streak** and **Total swipes**.
- **10 achievements** to unlock (see [Gamification](#gamification)).
- Toast notifications and a **confetti burst** for milestones.

### ⚙️ Settings
- Light / Dark / System appearance.
- Include or exclude **videos** and **screenshots** from the deck.
- Turn haptics on or off.
- **Start over from the oldest photo** (stats and achievements are kept).
- Show the intro again.
- Extra controls when you've only granted **limited** photo access.

---

## How it works (user flow)

```
 ┌──────────────┐   first launch   ┌─────────────────┐  access granted  ┌─────────────────────┐
 │  Onboarding  │ ───────────────▶ │ Permission view │ ───────────────▶ │  Main tabs          │
 │  (3 pages)   │                  │ "Allow access"  │                  │  Swipe · Pile ·     │
 └──────────────┘                  └─────────────────┘                  │  Stats · Settings   │
                                          ▲  denied → "Open Settings"   └─────────────────────┘
                                          └────────────────────────────────────┘
```

1. **Onboarding** – three short pages explain the idea: start from the
   beginning, swipe to decide, nothing is lost by accident.
2. **Permission** – the app asks for Photos access. If you deny it, the screen
   switches to an *Open Settings* button. When you come back from Settings the
   app re-checks access automatically.
3. **Swipe** – the main deck. Decide items one by one.
4. **Pile** – review the items you swiped left, rescue any mistakes, then delete
   them all at once.
5. **All caught up!** – when the whole library is reviewed you get a finished
   screen, a *Clean Slate* achievement, and options to review the pile or start
   over. New photos you take later appear in the deck automatically.

---

## Gestures and controls

| Action | Gesture | Button |
|--------|---------|--------|
| Keep | Drag right past ~110 pt, or flick right | 💚 heart |
| Delete (to pile) | Drag left past ~110 pt, or flick left | ❌ |
| Keep + Favorite | Drag up past ~143 pt, or flick up | ⭐ |
| Undo last decision | — | ↩️ (up to 50 steps) |
| View full screen | Press and hold the card (without moving it) | — |
| Zoom (full screen) | Pinch, or double-tap to toggle 2.5× | — |
| Close full screen | Swipe down, or tap ✕ | — |
| Unmute video | Tap the speaker icon on the card | — |

A drag that doesn't reach the threshold springs the card back to the center.

---

## Safety: how deletion works

Photo Tinder is designed so you **can't lose a photo by accident**:

1. **Swiping left never deletes anything.** It only moves the item into the
   app's own delete pile (stored in the app's database, not in Photos).
2. You can **undo** the swipe, **rescue** an item from the pile, or **return the
   whole pile** to the deck.
3. Deletion only happens when you tap **"Delete N items"** in the Pile tab, and
   **iOS itself shows a confirmation dialog** that you must approve.
4. Deleted items go to **Photos › Recently Deleted**, where iOS keeps them for
   **30 days** before removing them permanently. You can recover them there.
5. If you tap *Don't Allow* in the iOS dialog, nothing happens and your pile stays as it is.

---

## Gamification

### Streaks
Swipe at least once on a given day to keep your streak alive. Swipe on
consecutive days and the streak grows; miss a day and it resets. The app tracks
both your **current** and your **best** streak, and shows a toast like
*"5-day streak! Keep it going"*.

### Year milestones
Because the deck goes oldest-first, each time you reach a **new year** in your
library you get a *"Welcome to 2019"* toast.

### Achievements

| Achievement | How to unlock |
|-------------|---------------|
| 🖐️ **First Swipe** | Make your first swipe |
| 🔥 **Warming Up** | Swipe 100 items |
| ⚡ **Swipe Machine** | Swipe 1,000 items |
| 👑 **Legend** | Swipe 10,000 items |
| 🔥 **On Fire** | Reach a 7-day streak |
| ✨ **Unstoppable** | Reach a 30-day streak |
| 💾 **Breathing Room** | Free 1 GB |
| 💾 **Storage Hero** | Free 10 GB |
| 🕰️ **Time Traveler** | Swipe through 5 different years |
| ✅ **Clean Slate** | Review your whole library |

Unlocking an achievement, or confirming a deletion, triggers a toast and a confetti burst.

---

## Settings

| Setting | Default | Effect |
|---------|---------|--------|
| Appearance | System | Force Light or Dark mode, or follow the phone. |
| Include videos | On | When off, the deck shows photos only. |
| Include screenshots | On | When off, screenshots are skipped. |
| Haptics | On | Turns all vibration feedback on or off. |
| Start over from oldest photo | — | Forgets every keep/pile decision so the whole library comes back. Your lifetime stats and achievements are **not** reset. Already-deleted items stay deleted. |
| Show intro again | — | Replays onboarding. |
| Choose more photos / Allow full access | — | Only shown with *limited* access. |

---

## Privacy

- **No network calls of its own.** The only network use is PhotoKit downloading
  full-resolution originals from *your* iCloud Photo Library when needed.
- **No accounts, ads, tracking or analytics.**
- **No third-party dependencies.** The app uses only Apple frameworks.
- Decisions and stats are stored locally with **SwiftData** inside the app's
  sandbox. Deleting the app deletes that data. Your photos themselves are never
  copied anywhere.
- Photos permission text: *"Photo Tinder needs access to your library so you
  can swipe through your photos and choose which ones to delete."*

---

## Requirements

| | Minimum |
|---|---|
| iOS | **18.0** (uses the iOS 18 `Tab` API, `@Observable`, SwiftData, `sensoryFeedback`, `MagnifyGesture`) |
| Xcode | A recent Xcode with the iOS 18 SDK or newer (the project was created with Xcode 27) |
| Device | iPhone. The Simulator works but has a tiny sample library; a real device is far more fun. |

---

## Getting started

1. **Clone the repo**
   ```bash
   git clone https://github.com/visheshdahiyaofficial/Photo-Tinder.git
   cd Photo-Tinder
   ```
2. **Open the project**
   ```bash
   open "Photo Tinder.xcodeproj"
   ```
3. **Set up signing.** Select the *Photo Tinder* target → *Signing & Capabilities*,
   choose your own **Team**, and change the **Bundle Identifier**
   (currently `Tesh.Photo-Tinder`) to something unique to you.
4. **Pick a run destination** (your iPhone or an iOS 18+ simulator) and press **⌘R**.
5. On first launch, go through onboarding and tap **Allow access** (choose
   *Allow Full Access* for the best experience).

> **Tip:** To add test photos to the Simulator, drag image files from Finder
> onto the Simulator window. They'll be added to its Photos library.

There are no packages to install and no build scripts. It's a plain Xcode project.

---

## Project structure

```
Photo Tinder/
├── Photo Tinder.xcodeproj/          Xcode project
├── Photo Tinder/                    App source
│   ├── Photo_TinderApp.swift        @main entry; sets up the SwiftData container
│   ├── App/
│   │   ├── AppModel.swift           Root object: owns services, cross-cutting actions
│   │   ├── RootView.swift           Routes onboarding → permission → main tabs
│   │   └── MainTabView.swift        Tab bar, toast + confetti overlays
│   ├── Features/
│   │   ├── Deck/
│   │   │   ├── DeckView.swift              Swipe screen: header, card stack, buttons
│   │   │   ├── DeckViewModel.swift         Builds the deck, performs swipes, undo
│   │   │   ├── SwipeCardView.swift         Drag/flick gesture, fly-off animation, haptics
│   │   │   ├── MediaCardContent.swift      Image/video on a card + info badges
│   │   │   ├── SwipeFeedbackOverlay.swift  Full-screen animated swipe celebration
│   │   │   └── FullScreenMediaView.swift   Zoomable full-screen viewer
│   │   ├── Review/DeletePileView.swift     Delete pile grid + confirm delete
│   │   ├── Stats/StatsView.swift           Progress ring, stat tiles, achievements
│   │   ├── Settings/SettingsView.swift     Preferences and reset
│   │   └── Onboarding/
│   │       ├── OnboardingView.swift        3-page intro
│   │       └── PermissionView.swift        Photos permission prompt
│   ├── Models/
│   │   ├── MediaItem.swift          Lightweight value snapshot of a PHAsset
│   │   ├── SwipeRecord.swift        @Model: one decision per asset
│   │   ├── UserStats.swift          @Model: singleton row of stats/streaks
│   │   └── Achievement.swift        Achievement definitions and unlock rules
│   ├── Services/
│   │   ├── PhotoLibraryService.swift  PhotoKit wrapper (auth, fetch, load, delete, favorite)
│   │   ├── DecisionStore.swift        SwiftData persistence for decisions
│   │   ├── GamificationEngine.swift   Streaks, achievements, toast queue
│   │   └── AssetSizeEstimator.swift   Works out an asset's size on disk
│   ├── Shared/                       Reusable views and helpers
│   │   ├── ToastView.swift · ConfettiView.swift · Formatters.swift
│   │   └── Appearance.swift · RestartReviewDialog.swift
│   └── Assets.xcassets/              App icon (default, dark, tinted) and accent color
└── docs/
    └── ARCHITECTURE.md               In-depth technical documentation
```

---

## Architecture overview

Photo Tinder uses a small, service-oriented **MVVM** design built on Swift's
`@Observable` macro and SwiftData:

```
                     ┌───────────────────────── AppModel ─────────────────────────┐
                     │                                                             │
  SwiftUI views ───▶ │  PhotoLibraryService   DecisionStore   GamificationEngine   │
  (via @Environment) │        (PhotoKit)        (SwiftData)       (SwiftData)      │
                     │              ▲               ▲                  ▲           │
                     │              └──────── DeckViewModel ───────────┘           │
                     └─────────────────────────────────────────────────────────────┘
```

- **`PhotoLibraryService`** is the only code that talks to PhotoKit. It holds a
  lazy, oldest-first `PHFetchResult`, so even a 50,000-photo library loads instantly.
- **`DecisionStore`** saves one `SwipeRecord` per decided asset
  (`kept` / `pendingDelete` / `deleted`) and keeps an in-memory `Set` of decided
  IDs for fast lookups.
- **`DeckViewModel`** walks the fetch result with a cursor, skips anything
  already decided, and keeps a window of 6 upcoming cards.
- **`GamificationEngine`** updates streaks, years and achievements and queues toasts.
- **`AppModel`** wires them together and owns actions that touch several
  services (confirm delete, rescue, clear pile, restart review).

The source of truth for "has this been reviewed?" is simply **whether a
`SwipeRecord` exists** for an asset's `localIdentifier`. That makes resuming,
undoing and starting over simple and reliable.

👉 **For a detailed walkthrough of every component, the data model, gesture
math and performance tricks, read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).**

---

## Tech stack

| Area | Technology |
|------|------------|
| Language | Swift 5 |
| UI | SwiftUI (iOS 18 `TabView`/`Tab`, `ContentUnavailableView`, `TimelineView`, `Canvas`) |
| State | Observation framework (`@Observable`, `@Bindable`, `@Environment`) |
| Persistence | SwiftData (`@Model`, `@Query`, `FetchDescriptor`), `@AppStorage` for preferences |
| Photos | PhotoKit (`PHAsset`, `PHCachingImageManager`, `PHPhotoLibraryChangeObserver`, `PHAssetChangeRequest`) |
| Video | AVFoundation / AVKit (`AVQueuePlayer` + `AVPlayerLooper`, `VideoPlayer`) |
| Feedback | `sensoryFeedback` haptics, custom particle animations |
| Dependencies | **None** |

---

## Known limitations

- **File sizes are estimates when unavailable.** PhotoKit has no public size API,
  so the app reads `PHAssetResource`'s `fileSize` value and falls back to a rough
  estimate (from pixel count or video length) if that's missing. "Space freed"
  may therefore differ slightly from what iOS reports.
- **Space is freed after 30 days.** Deleted items sit in *Recently Deleted*
  until iOS purges them (or you empty that album yourself).
- **iPhone-first.** The layout works on iPad but isn't specially designed for it.
- **No automated tests yet.**
- **No duplicate or blur detection**. Every decision is yours.

---

## Roadmap ideas

- Smart grouping of near-duplicates and bursts
- "On this day" mode and jumping to a specific year
- Album and date-range filters
- Home-screen widget showing your streak and progress
- Unit tests for `DeckViewModel`, `DecisionStore` and `GamificationEngine`
- iPad-optimized layout

---

## Contributing

Issues and pull requests are welcome. For larger changes, please open an issue
first to discuss what you'd like to change. Keep the project dependency-free
and follow the existing structure (`Features/`, `Services/`, `Models/`, `Shared/`).

---

<p align="center">Made with ❤️ in SwiftUI by Vishesh</p>
