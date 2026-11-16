# Shutdown Cannon

A small macOS app that schedules a shutdown, with a twist: you fire a cannon to set the timer.
Hold to charge, release to launch, and the countdown starts.

I made it for a friend who often leaves big downloads running at the office and wanted the Mac to shut down on its own afterwards. It was also my first try at building a Mac app with AI (Cursor).

## Features
- Hold-to-charge cannon sets the shutdown delay
- Runs the real macOS `shutdown` command (asks for your admin password)
- Countdown in the menu bar, and you can cancel it at any time

## Run it
1. Open `ShutdownTimer.xcodeproj` in Xcode.
2. Pick your own signing team under Signing & Capabilities.
3. Press Run.

Built with SwiftUI and AppKit. Still a fun side project, so expect rough edges.
