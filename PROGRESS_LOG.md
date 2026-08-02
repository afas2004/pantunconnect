# PANTUN-CONNECT Progress Log

Running log of work done on the Flutter port, newest entries at the top. Kept alongside the
codebase so progress survives across chat sessions.

---

## 2026-07-26 (cont. 2)

### Fixed: Google Sign-In failing on iOS web (Safari and every other iOS browser)
Confirmed the underlying iOS-can't-load-the-web-app issue from the earlier session was fixed by
building with `flutter build web --wasm`, but Google Sign-In then failed with an error once the
app itself loaded. Root cause: web sign-in used Firebase's `signInWithPopup`, which opens a JS
popup window and needs third-party storage access to complete the credential exchange - iOS
Safari (and every other iOS browser, since they're all WebKit, not just Safari specifically)
blocks that by default under Intelligent Tracking Prevention, so the popup either never opens or
silently fails after the user picks an account. This didn't show up on desktop Chrome/Brave/Zen
because ITP is a WebKit-specific restriction.

Fixed by switching the web path to `signInWithRedirect` (a full-page navigation to Google and
back instead of a popup) - this is Firebase's own documented fix for Safari/iOS. Since a redirect
reloads the whole app, `signInWithGoogle()` can no longer return a result inline for web; added
`AuthRepository.completeGoogleRedirectSignIn()` (calls `getRedirectResult()`, then reuses the same
"create users/{uid} doc if missing" logic as the native Google sign-in path via a new shared
`_syncGoogleUser()` helper) and call it from `main.dart` right after Firebase init. Deliberately
not awaited before `runApp()` - it only matters on the one reload right after a redirect, and
SplashScreen's existing ~2.5s fade-in gives it plenty of time to finish in the background;
awaiting it there would otherwise delay every single app launch for a case that applies to almost
none of them. Native (Android/iOS app, not web) Google sign-in is untouched - still goes through
`google_sign_in` directly, which never had this popup/ITP problem.

Files touched: `lib/repositories/auth_repository.dart`, `lib/main.dart`.

## 2026-07-26 (cont.)

### Fixed: login/register/forgot-password cards stretched full width on desktop
`Login`/`Register`/`ForgotPassword` screens wrap their form in `Center` -> `SingleChildScrollView`
-> `NeomorphicBox`, with no max width anywhere in that chain. On mobile that's invisible since the
screen itself is narrow, but on a wide desktop viewport the loose width constraints flow all the
way down to each `TextField`, which fills all available width - dragging the whole card out to
the full browser width instead of reading as a normal centered login card. These three screens
were intentionally left alone during the earlier desktop-sidebar rollout ("login is fine") since
they don't need a sidebar, but they still needed this width cap.

Fixed by wrapping each `NeomorphicBox` in `ConstrainedBox(constraints: BoxConstraints(maxWidth:
420))` - keeps the card a normal size on wide viewports, no-op on anything narrower than 420.

Files touched: `lib/screens/auth/login_screen.dart`, `lib/screens/auth/register_screen.dart`,
`lib/screens/auth/forgot_password_screen.dart`.

## 2026-07-26

### Fixed (for real this time): yellow/red squiggly underlines under sidebar and chat text
The "browser spellcheck" theory from the previous entry was wrong - disproven by the account
owner's own testing (no spellcheck option on right-click; issue persists identically on Brave
*and* Zen Browser, both in incognito with extensions off, ruling out any single browser/extension).
Followed up with direct DOM inspection on the live site: zero real text DOM nodes exist anywhere
on the page (`document.querySelectorAll('*')` finds no element with the actual label text), zero
editable elements exist (`input`/`textarea`/`contenteditable` all empty), and Flutter's own hidden
accessibility layer (`flt-semantics-host`, `flt-text-editing-host`) is completely unbuilt
(`childCount: 0`, zero-size). So there was never a DOM text layer for any browser feature to
underline in the first place - that whole theory is conclusively wrong, not just unconfirmed.

Real cause: every `Text` widget added this session in the new sidebar/panel widgets
(`AppSidebar`/`_SidebarItemTile`, `_DesktopTrendingRail`, `_MoreFromAuthorPanel`, `_DraftsPanel`,
`_ConversationsRail`/`_ConversationTile`) set its own `color` but never set `decoration`. Flutter's
text-style resolution falls back to a debug-visible default (yellow squiggly underline, and red
text too if `color` is also left unset) whenever a `Text` resolves without those explicitly
covered - `_ConversationTile`'s conversation-name `Text` was missing `color` as well, which is why
it specifically showed up red on top of the underline while the rest only showed the underline.
This is painted by Flutter/CanvasKit itself, independent of the browser, which is exactly why it
looked identical across Chromium (Brave) and Gecko (Zen).

Fixed by wrapping each of those five widgets' content in
`DefaultTextStyle.merge(style: const TextStyle(decoration: TextDecoration.none), child: ...)`, and
adding the missing explicit `color: AppColors.textPrimary` to `_ConversationTile`'s name `Text`.
Verified with a brace/paren-balance check (no `flutter analyze` available in this sandbox) - needs
a real rebuild + redeploy to confirm the underlines are gone.

Files touched: `lib/widgets/app_sidebar.dart`, `lib/screens/main_shell.dart`,
`lib/screens/post_detail/post_detail_screen.dart`, `lib/screens/create/create_pantun_screen.dart`,
`lib/screens/chat/messaging_screen.dart`.

## 2026-07-25 (cont. 3)

### Fixed: cramped padding on the new right-panel cards
`NeomorphicBox` defaults to `padding: elevation/2` when none is given - fine for tightly-wrapped
controls like the sidebar's nav pill, but at `elevation: 3` that's 1.5px of padding on a text
card, which is why Trending Now, "More from this author", and the drafts panel all looked
cramped. None of the three cards I added this session (`_DesktopTrendingRail` in
`main_shell.dart`, `_MoreFromAuthorPanel` in `post_detail_screen.dart`, `_DraftsPanel` in
`create_pantun_screen.dart`) had passed an explicit `padding`, so all three had the same bug.
Added explicit padding to all three.

## 2026-07-25 (cont. 2)

### Fixed: Messages sidebar took two clicks to reach an actual conversation
Reproduced live via browser automation on the deployed site: clicking "Messages" in the desktop
sidebar landed on the bare `/chat-list` page, which has no sidebar of its own (it's the mobile
screen, unchanged and still correct there) - so the sidebar visibly disappeared, and reaching an
actual open conversation (with the sidebar back) took a second click into one of the chats.

Fixed by giving the sidebar's Messages item its own entry point: a new no-`chatId` `/messaging`
route (`AppSidebar` now does `context.go('/messaging')` instead of pushing `/chat-list`) that
renders the same shelled Messaging layout - sidebar, conversations rail - with an empty "Select a
conversation to start chatting" thread pane instead of a real thread. `MessagingScreen.onBack` is
now nullable and `chatId` can be `''` to represent this "nothing selected yet" state; the existing
`/messaging/:chatId` and `/chat-list` routes (and all of mobile) are unchanged.

### Investigated: yellow/red squiggly underlines under sidebar and chat text
Also reproduced live - the sidebar's nav labels have a yellow-ish squiggly underline, and chat
list entries (name + last message) have a red one, matching what was reported. This is browser
spellcheck/grammar-check rendering, not anything in the app's own drawing code: Flutter Web paints
all text as pixels on a canvas, but it also maintains an invisible, overlaid DOM "semantics" layer
purely for screen readers/accessibility - some browsers' native spellchecker (or an extension like
Grammarly/Edge's Editor) scans that hidden layer and paints its squiggly-underline decoration on
top of it, even though the text itself was never meant to be edited or spellchecked. It's cosmetic
only - doesn't affect functionality - and isn't something fixable from this codebase's Dart/CSS,
since the decoration is rendered entirely by the browser/extension outside Flutter's control. Left
as-is; flagged to the account owner with a suggested way to confirm the cause (toggle the
browser's spellcheck or any Grammarly-style extension off and see if it disappears).

## 2026-07-25 (cont.)

### Added: selectable text in Pantun AI chat bubbles
Question behind this one is worth recording: Flutter (mobile AND web) paints `Text` as pixels on
a canvas rather than using real browser text nodes, so nothing is selectable by default anywhere
in this app - it's not that the web build is "acting like a mobile app", every Flutter surface
starts out this way unless a screen opts in.

Wrapped the AI Assistant's message list in `SelectionArea` (built into Flutter since 3.3, no
package needed) - every `Text`/`Text.rich` under it, including `MarkdownLite`'s output, becomes
real click-and-drag (or long-press-drag on touch) selectable text with a native copy menu, and
selection can span across bubbles. Removed the per-bubble long-press-to-copy-whole-message
`GestureDetector` that existed before, since it would compete with `SelectionArea`'s own
long-press-drag-to-select gesture on touch, and is redundant now that any part of a message can
be selected and copied normally - the explicit copy icon on each bubble still works unchanged.

Only applied to Pantun AI per the request - other screens' plain `Text` widgets remain
unselectable for now, same tradeoff every other Flutter Web app makes unless explicitly opted in
per-screen.

## 2026-07-25

### Extended the desktop sidebar to Post Detail, Create Pantun, Messaging, and Settings
Follow-up to the Home/Search/AI/Profile sidebar work: those four screens are pushed routes
outside MainShell, so they hadn't gotten the sidebar at all - still full-bleed. Per direction
("shouldn't remove the side panel... each page has their own side panel or not based on their
feature"), extracted the sidebar into shared widgets so every logged-in screen can use it, and
gave three of the four a second panel backed by real data (no invented content):

- New `lib/widgets/app_sidebar.dart` (`AppSidebar`): the same six-item sidebar, now reusable.
  From inside MainShell, Home/Search/AI/Profile switch tabs in place as before; from any other
  screen those same items fall back to `context.go('/home?tab=N')` since tabs aren't separate
  routes and there's no other way to address one from outside MainShell. `app_router.dart`'s
  `/home` route now reads `?tab=` and passes it to `MainShell(initialTab: ...)`.
- New `lib/widgets/desktop_page_shell.dart` (`DesktopPageShell`, `kDesktopBreakpoint`): the
  reusable version of the LayoutBuilder-plus-sidebar pattern from MainShell. Takes a `builder`
  (gets `isDesktop` so a screen can skip something that would otherwise be duplicated), an
  optional `active` sidebar highlight, and optional `leftPanel`/`rightPanel` widgets. Below the
  breakpoint it's a no-op - renders exactly what `builder` returns.
- `main_shell.dart` now builds its sidebar from the shared `AppSidebar` instead of a private
  copy - one implementation, not two drifting in parallel.
- **Post Detail**: right panel = "More from this author", via the existing
  `PostRepository.getPostsByUser` lookup (same one the Profile grid already uses), filtered to
  exclude the current post. No sidebar item highlighted - a post isn't "any" tab.
- **Create Pantun**: right panel = your drafts, same `CreatePantunProvider.drafts` data moved
  from the cramped horizontal scroller (now hidden on desktop via the `isDesktop` builder flag)
  into a proper vertical list with room to actually read them.
- **Messaging**: gets a *left* panel (between the sidebar and the thread) listing every
  conversation, reusing `ChatListProvider` - a second instance scoped to this screen, same
  "fresh provider per route" pattern used everywhere else, not a shared/merged provider with
  ChatListScreen. Tapping a conversation does `context.go('/messaging/:id')` to switch without
  leaving the thread, the way WhatsApp Web/Messenger handle it. Sidebar highlights Messages.
- **Settings**: sidebar only, no second panel - a settings list has nothing genuine to fill one
  with, so none was added rather than padding it with filler.
- Login/Register/Forgot Password/Onboarding/Splash intentionally untouched - no sidebar, since
  there's nowhere to navigate to before signing in.

Visualized as a full desktop-wireframe HTML file first (`pantunconnect_desktop_wireframes.html`,
in this folder) and confirmed before implementing.

## 2026-07-24 (cont. 7)

### Added: real desktop web layout (sidebar + centered feed + trending rail)
Addresses the original "no responsive/desktop layout" audit finding - Home/Search/AI/Profile
used to stretch full-bleed edge to edge on wide screens with no max content width anywhere.
Visualized the target layout first (three-column, sidebar nav + capped feed + trending rail -
the pattern commercial feed apps use on desktop), then implemented it:

- `main_shell.dart`: wrapped the shell in a `LayoutBuilder` with a single breakpoint
  (`_desktopBreakpoint = 900`). Below it, everything is pixel-identical to before (IndexedStack +
  bottom pill nav, full width). At or above it: a new `_DesktopSidebar` (232px, wordmark, Home/
  Search/Pantun AI/Notifications/Messages/Profile nav items, a `NeomorphicButton` "Create pantun"
  action replacing the mobile FAB) on the left, the same four tabs centered and capped at 720px
  in the middle, and a new `_DesktopTrendingRail` (280px, only while the Home tab is active) on
  the right reusing the same live `HomeProvider.trending` data as the mobile carousel. The
  selected sidebar item is a raised `NeomorphicBox` pill rather than a flat color swap, to keep
  the embossed soft-UI look consistent with the rest of the app rather than introducing a flat
  "modern SaaS sidebar" style that would clash with it.
- `home_screen.dart`: added an `isDesktopLayout` flag (false by default, set by MainShell). When
  true, it skips the in-feed wordmark/notification/chat top bar, the inline trending carousel,
  and the floating "+" button - all three now live in the sidebar/rail instead, so nothing is
  duplicated. Mobile behavior (`isDesktopLayout: false`) is untouched.
- Search/Pantun AI/Profile needed no changes at all - centering and capping the shared
  `IndexedStack` at the MainShell level fixes their full-bleed problem automatically.

## 2026-07-24 (cont. 6)

### Added: unread-notification dot on the Home bell, ripple on notification cards
Two small cosmetic requests:

- `home_screen.dart`'s bell icon now shows a small red dot when there's at least one unread
  notification, via a `_NotificationBell` widget with a live `StreamBuilder` on
  `users/{uid}/notifications` filtered to `isRead == false` and capped at `limit(1)` - it only
  needs to know "any unread?", not a count, so this stays a single cheap real-time listener
  regardless of how many notifications pile up. Updates live: mark something as read and the dot
  disappears without needing a refresh.
- `notifications_screen.dart`'s `_NotificationCard` swapped its plain `GestureDetector` for a
  `Stack` with a transparent `InkWell` overlaid on top (same 16px border radius as the card).
  `NeomorphicBox` paints an opaque background, so a normal `InkWell`-wraps-content approach would
  have hidden the ripple underneath the card - stacking it on top instead makes the ripple/tap
  highlight visible, tinted to match each notification's own accent color (pink for likes, blue
  for comments, green for follows) instead of the default grey Material ripple.

## 2026-07-24 (cont. 5)

### Chat "doesn't save messages" - corrected understanding, deprioritized
Clarified with the account owner: chat sends/receives fine during normal use, and Firestore does
have the messages. The actual symptom is narrower - after a rebuild/redeploy, the messages appear
gone in the app even though they're still in Firestore. That points to the app landing on a
different (empty) chat thread between the same two people rather than real data loss - most likely
`ChatRepository.getOrCreateChat()` matching against whichever chat doc Firestore's unordered query
happens to return first, if more than one chat doc exists for that pair. Not confirmed further -
the account owner asked to leave this, since the demo doesn't need it fixed. The SnackBar/error-
surfacing fix from cont. 4 stands regardless (real improvement, unrelated to this specific symptom).

## 2026-07-24 (cont. 4)

### Investigated: "chat doesn't save messages"
Reviewed the whole chat path end to end: `ChatRepository` (`getOrCreateChat`, `sendMessage`,
`getMessages`), `ChatMessage`/`Chat` models, `MessagingProvider`, `UserConnectionsProvider.startChat`,
and `firestore.rules`' `chats`/`chats/{chatId}/messages` section. No logic bug found in any of
these - `getOrCreateChat` does create the chat doc (`set()`) before any message is sent, the
security rules correctly gate read/create/update on chat participants, and the message model's
`toMap`/`fromMap` round-trip cleanly.

Found and fixed a real bug that was hiding whatever the actual failure is: `messaging_screen.dart`'s
`_send()` called `provider.sendMessage(text)` without awaiting it and unconditionally cleared the
input right after - so on any failure (permission-denied, network error, anything) the input still
emptied like a normal send, the message just never appeared, and there was zero feedback. Fixed by
awaiting the send, only clearing the input on success, and showing a SnackBar with the actual error
on failure. Also fixed `MessagingProvider.sendMessage` to reset `error` to null at the start of each
attempt (it was never cleared, so a stale error from a previous failed send could otherwise leak
into a later successful one).

This doesn't yet pin down the root cause - I can't inspect the live Firebase project's actually
*deployed* rules from here, only the local `firestore.rules` file, and its own header comment notes
rules need a manual "Firebase Console > Firestore Database > Rules tab > Publish" step separate from
a normal app deploy. If that publish step was never done (or an older/stricter ruleset is live),
writes would fail with permission-denied, which used to fail completely silently. Next time a
message fails to send, the app will now show the real error in a SnackBar - that will say definitively
whether it's a rules/permission issue or something else.

## 2026-07-24 (cont. 3)

### Added: user search, and comment authors now tap through to their profile
Two gaps reported: the search bar's hint text ("Search hashtags, users, or keywords...") had
always promised user search, but `searchPosts` only ever queried the posts collection - there
was no way to actually find a person. Separately, comment authors in Post Detail had no tap
target at all, unlike post authors.

- Added `UserRepository.searchUsers()`: a Firestore prefix range query (orderBy + startAt/endAt)
  on `username`. This is a real server-side query, not a client-side scan, so it stays cheap
  regardless of collection size. It's case-sensitive (a Firestore limitation - no native
  contains/case-insensitive search without a duplicated lowercase field), so it also tries a
  capitalized variant of the typed query since most seeded usernames start with a capital letter.
  A `usernameLower` field would be the proper long-term fix if this needs to be more forgiving.
- `SearchProvider` now runs post and user search in parallel; `search_screen.dart` shows a
  "People" section (tap through to profile) above the "Pantun" post results.
- `post_detail_screen.dart`'s `_CommentItem` avatar and name are now tappable, wired to
  `onNavigateToUserProfile(comment.authorId)`, the same pattern already used for post authors.

## 2026-07-24 (cont. 2)

### Fixed: profile "Pantun" count stuck at 100 for high-volume accounts
Reported live: the Arkib Pantun account's profile showed "100" for its Pantun stat, but that
account (the seed curator) actually has ~5,642 posts in Firestore. Root cause: `getPostsByUser()`
has an intentional `.limit(100)` to cap read costs for the profile's post grid, but both
`ProfileProvider` and `UserProfileProvider` were reusing that same capped list's `.length` for
the stat number too - so any account past 100 posts always shows exactly 100.

Fix: added `PostRepository.getPostCountByUser()`, a Firestore `count()` aggregation query that
costs one aggregation read regardless of collection size (not a per-document read), and wired it
into both providers as a separate `userPostsCount`/`postsCount` field used only for the stat
display. The capped 100-post list is unchanged and still backs the actual grid.

## 2026-07-24 (cont.)

### Fixed: High-severity contrast issues confirmed on mobile
Per request, fixed the contrast items the mobile pass confirmed were real (not desktop-specific):
the softBlue/pastelPink/mintGreen pastel palette used as *foreground* text or meaningful-icon
color, and bare `Colors.grey` used for secondary/caption text.

Added to `app_theme.dart`: `textPrimary`, `textSecondary` (~7:1 vs Colors.grey's ~2.7:1),
`primaryAccentStrong` (~5.8:1 with white text, vs softBlue's ~1.8:1), `pastelPinkStrong` (~4:1),
`mintGreenStrong` (~3.4:1) - deeper counterparts of the existing pastels, kept separate so the
pastels can stay in use for backgrounds/shadows/tinted surfaces where they're fine.

Changed `NeomorphicButton`'s default background from `primaryAccent` to `primaryAccentStrong`,
which fixes Login and Register's primary buttons in one place. Then applied the new tokens
across: the "Pantun Connect"/"PANTUN CONNECT" wordmark (splash, home, onboarding), the
onboarding/login/register/forgot-password screens' text and buttons, the main-shell bottom nav
(all four tabs now swap color on selection, not just three - fixes the AI tab's weak indicator
too), the feed's like icon and secondary text, notification type icons, send buttons (chat,
post detail, AI assistant), Settings' icons and footer, Follow/Message buttons and avatar
backgrounds on profiles, and the AI markdown renderer's headers/list markers. Also upgraded
Create Pantun's "Detect with AI" from a barely-visible text link to an outlined icon chip.

Left untouched: loading spinners, decorative borders, tinted card/background fills, and the
inactive (unselected) bottom-nav icon color - those are either transient, purely decorative, or
an intentional "not selected" signal rather than a contrast defect.

## 2026-07-24

### Fixed: Register/Forgot Password "back" links did nothing
Found live during the mobile-viewport audit pass: tapping "Already have an account? Login" on
the Register screen did nothing. Root cause: `app_router.dart` navigated to `/register` (and
`/forgot-password`) with `context.go()`, which replaces the entire route stack, but both of those
screens navigate back with `context.pop()` - which had nothing left to pop to. Forgot Password's
back arrow had the identical latent bug, just not yet noticed.

Fix: Login now reaches Register and Forgot Password via `context.push()` instead of `go()`, so
`pop()` correctly returns to Login from either screen. One-line change per route in
`lib/routing/app_router.dart`.

### UI/UX audit part 3: mobile viewport pass + corrections
Repeated the visual walkthrough at phone width (390x844, iPhone 12 Pro emulation via DevTools,
screenshots provided directly since browser-automation resize wasn't reliable in this
environment) across Home, Search, AI Assistant, Profile, Settings, Login, and Register.

- The "no responsive layout" desktop finding does not occur on mobile - every screen shows
  correct margins and sizing, confirming the app was built mobile-first and holds up well there.
- The wordmark/CTA/AI-tab contrast issues are NOT desktop-specific - confirmed just as low-contrast
  at mobile width, so that fix applies everywhere.
- Correction: a desktop-pass finding claimed the Profile photo was a seed-data placeholder (stock
  photo instead of initials). The account owner confirmed it's their own real uploaded photo -
  that finding was removed from the report.
- New positives noted: AI Assistant's markdown rendering and bubble sizing look clean on mobile,
  Search's theme chips correctly pre-fill/filter, Settings gives Sign Out a subtle red-tinted
  danger cue worth reusing for Report/Block.

All three passes (code review, desktop visual, mobile visual) are now combined into
`PantunConnect_UIUX_Audit.docx` in this folder, including the Register/Forgot Password fix above.

## 2026-07-23

### UI/UX audit part 2: visual pass on the live deployment
Followed up the code-only audit below by actually clicking through pantunconnect.web.app in
Brave (via Claude in Chrome) at a normal desktop width (1425px) - splash, onboarding, login,
register, home feed, search/explore, AI assistant, profile, edit profile, notifications, chat
list, create pantun. Confirmed most code-based predictions and surfaced things only visible when
rendered:

- **Biggest finding**: the app has zero responsive/desktop layout. Auth screens float as a
  narrow mobile-width card in a mostly-blank desktop canvas; Home/Search/AI/Profile instead
  stretch full-bleed edge to edge across the whole viewport with no max-content-width anywhere.
  Feed post cards and AI chat bubbles end up ~1000-1400px wide for 2-3 lines of text.
- Confirmed pastel-as-foreground contrast problem visually: the "Pantun Connect" wordmark, the
  onboarding headline, and the softBlue primary buttons (Login, Get Started) are genuinely hard
  to read at a glance; the feed's heart/share icons nearly disappear against white cards.
- Confirmed avatar shape inconsistency side by side: rounded-square tile on feed post cards vs.
  circular everywhere else (profile, chat, edit-profile).
- New (visual-only): seeded profile picture URLs point to an unrelated stock photo (sky + lamp
  post) instead of being empty, so initials never render for those seeded accounts - a seed-data
  content issue, not code.
- New (visual-only): found 3 duplicate "jinbutsu liked your pantun" notifications at the exact
  same timestamp in live data - direct evidence the pre-fix like-spam bug already produced junk
  data in Firestore before today's fix landed. Needs a one-off cleanup script (recompute
  `likesCount` from actual `likes` subcollection size per post, dedupe identical notifications).
- New (visual-only): page transitions (e.g. Home -> Messages, Onboarding -> Login) cross-fade
  with both screens' text overlapping mid-animation, a "double exposure" look.
- Positive: "Post Pantun" (mint green) is the one button in the app with proper visual weight/
  contrast - a good reference for fixing the other CTA buttons rather than a problem itself.
- "Detect with AI" on Create Pantun is a plain muted-grey text link, easy to miss for what's
  meant to be a headline feature.

Full findings + fixes delivered as a table in chat, then combined with the earlier code-only
audit into a single report: `PantunConnect_UIUX_Audit.docx` (in this folder). No code changes
made yet. Next: repeat the visual pass at mobile viewport width.

### UI/UX audit (design-ui-designer persona)
Read `agency-agents/design/design-ui-designer.md` and reviewed the theme system, `NeomorphicBox`,
and all major screens (home/feed, post card, profile, auth, create-pantun, chat, notifications,
settings, AI assistant). Findings delivered as a table in chat, covering: pastel palette used as
foreground text/icon color (likely fails WCAG AA contrast), no shared design tokens (radius/
elevation/type picked ad hoc per screen), inconsistent avatar shape language, dead affordances
(comment/share icons with no handler), weak selected-state indicator on the AI nav tab, silent
failures on Report/Block (no user feedback), mixed form design language (stock Material inputs
inside neomorphic shells), and missing accessibility semantics/tooltips on icon-only buttons.
No code changes made yet — audit only. Fixes to be scheduled from the table.

### Fixed: like button incrementing without limit on repeated taps
Root cause: `PostRepository.likePost()` wrote to `posts/{id}/likes/{userId}` on every tap but
never checked whether that doc already existed, so each tap did an unconditional
`likesCount + 1` in Firestore with no ceiling and no way to undo a like.

Fix:
- Replaced `likePost()` with a transactional `toggleLike()` in `post_repository.dart` that checks
  the like doc first (like -> unlike -> like ...).
- Added `isLiked` to the `Post` model so the heart icon reflects state (filled vs. outline).
- `HomeProvider` / `PostDetailProvider` now do an optimistic toggle and ignore further taps on a
  post while its request is in flight, with revert-on-failure so the count can't drift from
  Firestore.

Files touched: `lib/repositories/post_repository.dart`, `lib/models/post_model.dart`,
`lib/providers/home_provider.dart`, `lib/providers/post_detail_provider.dart`,
`lib/screens/home/post_card.dart`, `lib/screens/home/home_screen.dart`.

---

## Prior sessions (condensed)

- Scaffolded the Flutter project (pubspec, structure, docs) and ported data models, repositories,
  and services (Gemini, preferences, drafts) from the original Kotlin app.
- Built the shared neomorphic theme/widgets, all ChangeNotifier providers, and every screen.
- Wired routing, `main.dart`, and `firebase_options.dart`; set up web deployment
  (`firebase.json`, `storage.rules`) with a final verification pass.
- Re-fetched the real Kotlin source for screens that had been reconstructed from memory and
  rewrote them 1:1, updating providers/models to match exact Kotlin data and logic.
- Cataloged the CSC575 pantun dataset, added the real 6-theme taxonomy with Gemini
  auto-classification, and generated Firestore seed data from the real corpus.
- Fixed Google Sign-In wiring and the Gemini AI chatbot config.
- Added the followers/following data layer and screen, a "start chat with friend" entry point,
  and fixed the chat list's display (was showing a hardcoded name for every conversation).
- Fixed profile picture / image picker UI gaps.
- Wired real notification writes for like/comment/follow events.
- UX rework: persistent bottom-nav shell (replacing pushed routes), settings-screen sign-out,
  removed the dark-mode toggle (light-theme only), live "Trending Now" sampled from real posts.
