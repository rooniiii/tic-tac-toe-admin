# NEON XO Admin

Admin app for the **NEON XO** tic-tac-toe game (`tic-tac-toe`). Built with
Flutter and Firebase, using the same Firebase project as the game.

> Screenshots: add images to `docs/screenshots/` and link them here.

## Features

**Access**
- Admin login with email and password, and password reset
- Only accounts in the `admins` collection can sign in
- Sidebar on wide screens, drawer menu on phones

**Admins** (all admins have the same permissions)
- Create a new admin with name, email and temporary password
- Grant admin access to an existing player, or to any login by UID
- List and search admins by name, email or UID
- Send an admin a password reset email
- Remove admin access (the last admin cannot be removed)

**Players**
- List players (newest first, loaded 25 at a time) with their stats
- Total / active / blocked counts
- View a player's full profile
- Edit a player's display name
- Send a player a password reset email
- Block or unblock a player
- Delete a player, with or without their game history
- View, edit and delete player bios

**Insight**
- Dashboard with totals and the latest admin actions
- Statistics with charts: games per day, results split, most active players
- Per-player statistics, sortable by games, wins or win rate
- Game history with search and filters
- **Activity Log**: every admin action, with who did it and when

## Project structure

```
lib/
  main.dart                   Login check and navigation shell
  models/                     AdminModel, UserModel, GameModel
  services/
    admin_service.dart        Login, create / add / remove admins
    user_service.dart         Players: paging, counts, block, delete
    stats_service.dart        Dashboard totals and chart data
    game_service.dart         Game history
    admin_log_service.dart    Activity log
  screen/                     One file per screen
  widgets/
    admin_drawer.dart         Navigation menu
    simple_charts.dart        Bar charts drawn with plain Flutter widgets
    load_more_button.dart     "Load more" row for paged lists
  theme/app_theme.dart        Colours and theme shared by all screens
```

## Setup

1. Install Flutter (Dart SDK 3.8 or newer), then run `flutter pub get`.
2. Firebase config for project `tic-tac-toe-4ab92` is already included.
3. The security rules live in the game repo (`tic-tac-toe/firestore.rules`)
   and must be published, see that README.
4. **First admin:** if there is no admin yet, create a login in Firebase
   console → Authentication, then add a document `admins/<that UID>` with
   the field `role: "admin"`. After that, new admins can be created from
   the app.
5. `flutter run`

## Design notes

**Creating admins without a server.** Creating a login with Firebase's
normal sign-up call would sign the current admin out. The app creates new
logins through a second, separate Firebase connection, so the current admin
stays signed in. If a later step fails, the new login is deleted again.

**Blocking players.** On the free plan a login cannot be disabled from the
app. Instead the app sets `isBlocked` on the player; the security rules then
reject everything the player tries to save, and the game signs them out.
See the game README for details.

**Keeping Firebase reads low.** The free plan allows 50,000 reads per day.
Lists load 25–30 items at a time with "Load more", and totals use count and
sum queries (one read per 1,000 documents) instead of reading every
document.

**Activity log.** Every change made by an admin is written to `admin_logs`.
The rules allow admins to add entries but never to change or delete them,
so the log can be trusted.

## Known limitations

- Search on the Players, Statistics and Game History screens only covers
  the items already loaded; use "Load more" to search further.
- Deleting a player removes all their data but not their Firebase login;
  it can be removed by hand in Firebase console → Authentication.
- Only Android is configured.
