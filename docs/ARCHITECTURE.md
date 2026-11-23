# Photo Tinder – Architecture & Technical Guide

This document explains how Photo Tinder is built: the object graph, the data
model, how the deck is assembled, how gestures and animations work, and the
performance and safety decisions behind them. For the user-facing overview,
see the main [README](../README.md).

---

## Contents

1. [Design goals](#1-design-goals)
2. [App launch and routing](#2-app-launch-and-routing)
3. [Object graph](#3-object-graph)
4. [Data model](#4-data-model)
5. [PhotoLibraryService (PhotoKit layer)](#5-photolibraryservice-photokit-layer)
6. [DecisionStore (persistence layer)](#6-decisionstore-persistence-layer)
7. [DeckViewModel (building the deck)](#7-deckviewmodel-building-the-deck)
8. [The swipe card: gestures and animation](#8-the-swipe-card-gestures-and-animation)
9. [Swipe feedback overlay](#9-swipe-feedback-overlay)
10. [Media loading and caching](#10-media-loading-and-caching)
11. [Delete pile and batch deletion](#11-delete-pile-and-batch-deletion)
12. [GamificationEngine](#12-gamificationengine)
13. [Reacting to library changes](#13-reacting-to-library-changes)
14. [Preferences (`@AppStorage` keys)](#14-preferences-appstorage-keys)
15. [Lifecycle of a single swipe](#15-lifecycle-of-a-single-swipe)
16. [Extending the app](#16-extending-the-app)

---

## 1. Design goals

| Goal | How it's achieved |
|------|-------------------|
| **Never lose a photo by accident** | Left swipes only mark items `pendingDelete`; real deletion is a separate, OS-confirmed batch step. |
| **Resume anywhere, instantly** | A decision is a row in SwiftData keyed by `PHAsset.localIdentifier`. The deck is rebuilt by skipping decided IDs. |
| **Handle huge libraries** | `PHFetchResult` is lazy; the deck only materializes a window of 6 cards. |
| **Swipes must feel instant** | `PHCachingImageManager` prefetches upcoming cards; opportunistic delivery shows a fast preview first. |
| **Zero dependencies** | Apple frameworks only. |
| **Small, readable code** | ~2,400 lines of Swift, split by feature, with one service per concern. |

---

## 2. App launch and routing

```swift
@main struct Photo_TinderApp: App {
    WindowGroup { RootView() }
        .modelContainer(for: [SwipeRecord.self, UserStats.self])
}
```

`RootView` decides what to show:

```
hasOnboarded == false            → OnboardingView
AppModel not yet created         → ProgressView (one frame; created in .task)
library.isAuthorized == false    → PermissionView
otherwise                        → MainTabView
```

- `AppModel` is created lazily in `.task` because it needs the SwiftData
  `ModelContext` from the environment.
- `RootView` watches `scenePhase`; when the app becomes `.active` it calls
  `library.refreshAuthorization()`. This is how the app notices that the user
  turned on Photos access in the Settings app and came back.
- The user's chosen `Appearance` is applied with `.preferredColorScheme`.

---

## 3. Object graph

```
AppModel  (@Observable, injected with .environment(app))
├── library : PhotoLibraryService   — PhotoKit: auth, fetch, images, video, delete, favorite, change observer
├── store   : DecisionStore         — SwiftData CRUD for SwipeRecord + in-memory decidedIDs set
├── game    : GamificationEngine    — UserStats, streaks, achievements, toast queue, confetti trigger
└── deck    : DeckViewModel         — card window, cursor, undo stack; depends on library + store + game
```

`AppModel` also holds tab selection (`selectedTab`), `isDeleting` and
`errorMessage`, and implements the actions that span more than one service:

| Method | What it does |
|--------|--------------|
| `requestAccess()` | Asks for PhotoKit access, then reloads the deck. |
| `applyFilters()` | Refetches with the new video/screenshot filters, reloads the deck. |
| `confirmDeletion()` | Deletes all `pendingDelete` assets in one change request, marks them `deleted`, clears undo, credits stats. Ignores `PHPhotosError.userCancelled`. |
| `rescue(id)` | Moves one pile item to `kept`. |
| `clearPile()` | Removes all `pendingDelete` records, so those items return to the deck. |
| `restartReview()` | Deletes **all** `SwipeRecord`s, resets `libraryCompleted`, clears undo, reloads and switches to the Swipe tab. Lifetime stats are kept. |

Views read state through `@Environment(AppModel.self)`. Views that need live
SwiftData results, such as the pile badge and the pile grid, use `@Query` directly.

---

## 4. Data model

### `SwipeRecord` (`@Model`)

One row per asset the user has decided on. **No row means "never swiped".**

| Field | Type | Notes |
|-------|------|-------|
| `assetID` | `String` (`@Attribute(.unique)`) | `PHAsset.localIdentifier` |
| `decisionRaw` | `String` | Raw value of `SwipeDecision`; stored as a string so `#Predicate` / `@Query` can filter on it |
| `decidedAt` | `Date` | Used to sort the pile (newest first) |
| `isVideo` | `Bool` | For the video badge in the pile grid |
| `byteSize` | `Int64` | Size at decision time; summed for "Delete N items · X GB" and "Space freed" |
| `assetCreationDate` | `Date?` | Kept for future features |

```swift
enum SwipeDecision: String { case kept, pendingDelete, deleted }
```

- **kept** – swiped right or up. Hidden from the deck.
- **pendingDelete** – swiped left. Shown in the Pile tab.
- **deleted** – confirmed and removed from Photos. Kept as history.

### `UserStats` (`@Model`, single row)

`totalSwipes`, `totalDeleted`, `bytesFreed`, `currentStreak`, `longestStreak`,
`lastActiveDay` (start of day), `yearsVisited: [Int]`,
`unlockedAchievements: [String]`, `libraryCompleted`.

### `MediaItem` (value type)

An immutable snapshot of the `PHAsset` fields the UI needs: `id`,
`creationDate`, `isVideo`, `duration`, `isFavorite`, `isLivePhoto`,
`isScreenshot`, plus a computed `year`. Using a value type keeps PhotoKit
objects out of SwiftUI diffing.

### `Achievement` (enum)

Ten cases, each with `title`, `detail`, an SF Symbol and an
`isEarned(by: UserStats)` rule. Adding an achievement only means adding a case
and filling in its four switch statements.

---

## 5. PhotoLibraryService (PhotoKit layer)

**Authorization** uses `.readWrite` access level. `isAuthorized` is true for
both `.authorized` and `.limited`; `isLimited` drives the "You've only shared
some photos" banner and the limited-library picker.

**Fetching**: `refetch()` builds one `PHFetchResult<PHAsset>`:

- sorted by `creationDate` **ascending** (oldest first)
- `mediaType == image`, or `image OR video` if videos are enabled
- when screenshots are excluded: `(mediaSubtypes & photoScreenshot) == 0`

`PHFetchResult` is lazy, so this costs almost nothing even for very large
libraries. Assets are read by index (`asset(at:)`) or by ID (`asset(withID:)`).

**`countDecided(in:)`** enumerates the fetch once to count how many assets in
the *current filter* already have a decision. That keeps the progress bar
correct when filters change.

**Loading**: see [§10](#10-media-loading-and-caching).

**Mutations**:
- `delete(ids:)` – a single `performChanges` with `PHAssetChangeRequest.deleteAssets`.
- `setFavorite(_:id:)` – sets `isFavorite` through a change request.

**Change observation**: see [§13](#13-reacting-to-library-changes).

---

## 6. DecisionStore (persistence layer)

A thin wrapper over `ModelContext`:

- On init it loads every `SwipeRecord` once to build **`decidedIDs: Set<String>`**.
  The deck checks this set for every candidate asset, so it has to be O(1).
- `record(_:decision:byteSize:)` inserts or updates (upsert) and adds to the set.
- `remove(ids:)` deletes records **and** removes the IDs from the set. This is
  how undo, clear-pile and restart put items back into the deck.
- `setDecision(_:for:)` changes the decision without touching the set. It's
  used for `pendingDelete → deleted` and `pendingDelete → kept` (rescue).
- `records(with:)` / `count(of:)` filter on `decisionRaw`.
- Every write calls `context.save()` right away, so progress survives the app
  being killed at any moment.

---

## 7. DeckViewModel (building the deck)

```
fetchResult (oldest → newest):  [a0][a1][a2][a3][a4][a5][a6][a7][a8] …
decidedIDs:                       ✓   ✓       ✓
cursor ─────────────────────────────────────▶
cards (window of 6):                     [a2][a4][a5][a6][a7][a8]
                                          ▲ top card
```

- **`reload()`** resets `cursor = 0`, empties `cards`, recomputes
  `totalCount` and `reviewedCount`, then calls `fill()`. If the deck is empty
  and the library isn't, it awards *Clean Slate*.
- **`fill()`** moves the cursor forward until the window holds 6 cards,
  skipping any asset in `decidedIDs` (or already in the window), then updates
  the image cache for those cards.
- **`perform(action, on: id)`**:
  1. Ignores stale callbacks: `id` must match `cards.first`.
  2. Removes the top card and records it (`pendingDelete` for delete,
     otherwise `kept`) with its byte size.
  3. For `.favorite` on a non-favorite item, sets the iOS Favorite flag.
  4. Pushes onto the undo stack (capped at **50**).
  5. Increments `reviewedCount`, notifies `GamificationEngine`, refills.
- **`undo()`** pops the last entry, deletes its record, un-favorites if the
  swipe had favorited it, puts the item back on top, and decrements the counters.
- **`clearUndoHistory()`** runs after a real deletion, because deleted assets can't come back.
- **`requestedAction`** connects the buttons to the card animation: a button
  sets it, the top `SwipeCardView` sees the change, flies off, and then calls
  `perform`. Buttons and gestures therefore share the same animation and code path.

Progress = `reviewedCount / totalCount`, both measured against the current filter.

---

## 8. The swipe card: gestures and animation

`SwipeCardView` handles one card. Key constants and rules:

| Rule | Value |
|------|-------|
| Horizontal threshold | **110 pt** |
| Keep / delete fires when | `translation.width > 110` **or** `predictedEndTranslation.width > 275` (2.5×) |
| Favorite fires when | the drag is mostly vertical **and** (`translation.height < −143` (1.3×) **or** `predicted.height < −330` (3×)) |
| Rotation while dragging | `offset.width / 18` degrees, anchored at the bottom |
| Fly-off | 0.22 s ease-in to 1.6× screen width sideways, or 1.4× height upward |
| Snap back | spring (response 0.35, damping 0.7) |

Details worth knowing:

- **Predicted end translation** lets a short, fast flick count as a swipe.
- **Cancelled drags** (for example a system gesture taking over) never call
  `onEnded`. A `@GestureState isDragging` resets on its own, and an `onChange`
  on it springs the card back, so a card can't get stuck off-center.
- **Long press** (0.5 s) runs at the same time as the drag but only opens the
  full-screen viewer if the card hasn't moved and isn't flying.
- Only the top card accepts touches (`allowsHitTesting(isTop && !isFlying)`),
  and while the full-screen viewer is open the top card is made inactive so its
  video pauses.
- **Haptics** with `.sensoryFeedback`: `.selection` when crossing the threshold,
  `.impact(.medium)` on delete, `.success` on keep/favorite,
  `.impact(.light)` on long-press. All of them check the `hapticsEnabled` preference.
- The stack shows 3 cards: each one lower is scaled by −5% and moved 14 pt down.

---

## 9. Swipe feedback overlay

`SwipeFeedback` is an `@Observable` state machine with four phases:

```
idle ──drag──▶ dragging ──commit──▶ burst (420 ms) ──▶ fading (1 s) ──▶ idle
                  ▲  │
                  └──┘ progress 0…1 while the finger moves
```

- **Layout**: one large center icon (60% of the screen width) plus 6–8 small
  icons placed around an ellipse with random jitter, size, rotation and
  staggered delays. A new random layout is made whenever the direction changes.
- **Progress** reaches 1 at **1.6× the swipe threshold**
  (`reachPastThreshold`), so the overlay keeps growing after the swipe point
  instead of maxing out early.
- **Opacity while dragging** is `log10(1 + 9·p)`, where `p` is progress to the
  threshold. It fades in quickly and is fully opaque exactly at the threshold.
- **Scale and spread** use an ease-out curve `1 − (1 − p)²`.
- **Ambient motion**: a `TimelineView(.animation)` adds a gentle sway, bob and
  pulse (per-particle phase `seed`), so the overlay never looks frozen while a
  finger rests on the card.
- **Burst**: spring (0.34 / 0.55) with per-particle delays. **Fade**: small
  icons leave first, one after another, then the main one; particles drift outward.
- A `generation` counter cancels stale timers when swipes happen quickly one after another.
- Button-triggered swipes render one empty "dragging" frame first, so the pop
  has a starting state to animate from.
- **Reduce Motion** turns off sway, drift and the fading scale-up.
- The overlay is `allowsHitTesting(false)` and `accessibilityHidden(true)`.

Colors and symbols: keep = green 👍 `hand.thumbsup.fill`, delete = red 👎
`hand.thumbsdown.fill`, favorite = orange ⭐ `star.fill`.

---

## 10. Media loading and caching

**Images** – `images(for:targetSize:contentMode:)` returns an
`AsyncStream<UIImage>`:

- `deliveryMode = .opportunistic` → PhotoKit sends a quick, low-quality image
  first, then the final one. The stream yields both and finishes after the
  non-degraded image (or when cancelled or on error).
- `isNetworkAccessAllowed = true` → iCloud-only originals are downloaded.
- The stream's `onTermination` cancels the PhotoKit request, so when a view's
  `.task(id:)` is cancelled (for example the card was swiped away) the request stops too.

Target sizes:
- Cards: the card's size × display scale.
- Full-screen viewer: **3×** the screen size × display scale, so zooming stays sharp.
- Pile thumbnails: 120 pt × display scale, aspect-fill.

**Prefetching** – `updateCache(for:targetSize:)` compares the current card
window with the previously cached IDs and calls
`startCachingImages` / `stopCachingImages` on `PHCachingImageManager` for just
the difference. When the target size changes it clears everything and starts over.

**Video** – `videoAsset(for:)` wraps `requestAVAsset` in a checked continuation.
On cards, an `AVQueuePlayer` + `AVPlayerLooper` plays muted on a loop through a
control-free `AVPlayerLayer` (`PlayerLayerView`). Only the top card plays, and
it pauses when it stops being the top card or disappears. The full-screen view
uses AVKit's `VideoPlayer` with normal controls.

**Size estimation** – `AssetSizeEstimator.byteSize(of:)` adds up
`PHAssetResource`'s `fileSize` value (read with key-value coding, since PhotoKit
has no public size API). If that's 0, it estimates
`duration × 1.5 MB/s` for videos or `pixels / 4` bytes for photos.

---

## 11. Delete pile and batch deletion

```
swipe left ──▶ SwipeRecord(.pendingDelete) ──▶ Pile tab
                                   │
           ┌───────────────────────┼─────────────────────────┐
           ▼                       ▼                         ▼
   rescue → .kept       "Keep all & return"        "Delete N items · X GB"
                         → records removed          → PHPhotoLibrary.performChanges
                         → back in deck                (one iOS confirmation)
                                                     ├─ allowed  → .deleted, stats++, confetti
                                                     ├─ cancelled → nothing changes
                                                     └─ error     → alert
```

- All IDs go into **one** `PHAssetChangeRequest.deleteAssets` call, so iOS
  shows a single prompt for the whole batch.
- `delete(ids:)` returns early if none of the IDs exist any more (for example
  they were already deleted in the Photos app).
- After success the undo stack is cleared, since you can't undo a real deletion.
- `GamificationEngine.registerDeletion` adds to `totalDeleted` / `bytesFreed`,
  shows a "*X freed*" toast with confetti and checks storage achievements.

---

## 12. GamificationEngine

- Loads the single `UserStats` row, or creates it on first launch.
- **`registerSwipe(item:)`**
  - Streak: if the last active day was yesterday, `+1`; if it was earlier,
    reset to `1`; if it was today, no change. Updates `longestStreak` and shows a
    toast for streaks above 1.
  - `totalSwipes += 1`.
  - New year in `item.year` → added to `yearsVisited`, with a "*Welcome to YYYY*"
    toast (except for the very first year).
  - Checks achievements.
- **`activeStreak()`** returns the streak only if the last active day was today
  or yesterday, otherwise 0, so the Stats screen never shows a stale streak.
- **`undoSwipe()`** decrements `totalSwipes`. Streaks and years aren't rolled back.
- **Toast queue**: `announce` shows the event right away if nothing is on
  screen, otherwise queues it. `MainTabView` auto-dismisses each toast after
  2.5 s (or on tap), which shows the next one. Events marked `celebrate`
  increment `confettiTrigger`, which `ConfettiView` watches.
- **ConfettiView**: 90 rectangles drawn in a `Canvas` with simple projectile
  physics (gravity 700 pt/s², random velocity and spin), fading out over 3 s.

---

## 13. Reacting to library changes

`PhotoLibraryService` registers as a `PHPhotoLibraryChangeObserver` once access is granted.

In `photoLibraryDidChange` it hops to the main actor, swaps in
`fetchResultAfterChanges`, and calls `onStructureChange` **only** for
structural changes (items inserted or removed, or non-incremental changes).
Metadata-only changes, such as favoriting an item from the deck, do **not**
rebuild the deck. Otherwise every up-swipe would reset the card stack.

`AppModel` connects `onStructureChange` to `deck.reload()`, so new photos
appear in the deck and photos deleted elsewhere disappear from it.

---

## 14. Preferences (`@AppStorage` keys)

| Key | Type | Default | Used by |
|-----|------|---------|---------|
| `hasOnboarded` | Bool | false | `RootView`, `SettingsView` ("Show intro again") |
| `appearance` | `Appearance` | `.system` | `RootView`, `SettingsView` |
| `includeVideos` | Bool | true | `PhotoLibraryService.refetch()` |
| `includeScreenshots` | Bool | true | `PhotoLibraryService.refetch()` |
| `hapticsEnabled` | Bool | true | `SwipeCardView` |

Defaults for the two filter keys are registered in `UserDefaults` so
`bool(forKey:)` returns `true` before the user ever opens Settings.

---

## 15. Lifecycle of a single swipe

```
finger drags card
  └─ SwipeCardView.onChanged → offset, rotation
       └─ onDrag(action, progress) → SwipeFeedback.drag → overlay builds up
finger lifts past threshold
  └─ fling(.keep)
       ├─ haptic (.success)
       ├─ onFling → SwipeFeedback.commit → burst → fade
       └─ 0.22 s fly-off → onDecide(.keep)
            └─ DeckViewModel.perform(.keep, on: id)
                 ├─ DecisionStore.record(.kept, byteSize)  → SwiftData save
                 ├─ undoStack.push
                 ├─ GamificationEngine.registerSwipe        → streak/year/achievement toasts
                 └─ fill() → next asset enters the window, cache updated
                      └─ SwiftUI animates the stack forward (spring 0.4 / 0.8)
```

---

## 16. Extending the app

- **New swipe action**: add a case to `SwipeAction`, handle it in
  `SwipeCardView.drag`/`fling`, `DeckViewModel.perform`/`undo`, and the overlay's
  `symbol(for:)` / `color(for:)`.
- **New filter**: add an `@AppStorage` key and a predicate in
  `PhotoLibraryService.refetch()`, add a toggle in `SettingsView` that calls
  `app.applyFilters()`, and register its default.
- **New achievement**: add an `Achievement` case. `GamificationEngine` checks
  all cases automatically. If it needs new data, add a field to `UserStats`
  (SwiftData migrates added properties that have default values).
- **New stat tile**: add a `StatTile` in `StatsView`.
- **Testing**: `GamificationEngine.registerSwipe(item:now:)` and
  `activeStreak(now:)` take an injectable date, which makes streak logic easy
  to unit-test with an in-memory `ModelContainer`.
