# issue w/ moving and copying files

upon moving a file into another directory, the app hangs and throws the following output

```
commander on 󰊢 on master 392ea49 via swift v6.3.3 05:16 AM
 󱞪 : swift run
warning: 'commander': found 1 file(s) which are unhandled; explicitly declare them as resources or exclude from the target
    /Volumes/Femboy >_</Developer/Swift/commander/TODO.md
[1/1] Planning build
Building for debugging...
[4/4] Emitting module Commander
Build of product 'Commander' complete! (1.46s)
Swift/Optional.swift:377: Fatal error: unsafelyUnwrapped of nil optional

💣 Program crashed: System trap at 0x00000001972f91d0

Platform: arm64 macOS 26.6 (25G72)

Thread 0 crashed:

  0 0x00000001972f91d0 closure #1 in closure #1 in _assertionFailure(_:_:file:line:flags:) + 400 in libswiftCore.dylib
  1 0x00000001972f8ca4 _assertionFailure(_:_:file:line:flags:) + 276 in libswiftCore.dylib
  2 0x00000001972dc570 Optional.unsafelyUnwrapped.getter + 416 in libswiftCore.dylib
  3 BrowserPaneViewController.playSuccessSound() + 108 in Commander at /Volumes/Femboy >_</Developer/Swift/commander/Sources/Commander/Windows/Main/MainViewController.swift:1246:47

  1244│   private func playSuccessSound() {
  1245│       /// If `Crystal` doesn't exist theres something wrong with your Mac, so this is fine.
  1246│       NSSound(named: NSSound.Name("Crystal")).unsafelyUnwrapped.play()
      │                                               ▲
  1247│   }
  1248│

  4 BrowserPaneViewController.handleDrop(urls:) + 364 in Commander at /Volumes/Femboy >_</Developer/Swift/commander/Sources/Commander/Windows/Main/MainViewController.swift:1032:7

  1030│         reloadSiblingPanesAfterMove(from: sourceFolders)
  1031│       }
  1032│       playSuccessSound()
      │       ▲
  1033│       return true
  1034│     } catch {

  5 BrowserPaneViewController.tableView(_:acceptDrop:row:dropOperation:) + 828 in Commander at /Volumes/Femboy >_</Developer/Swift/commander/Sources/Commander/Windows/Main/MainViewController.swift:1015:12

  1013│       return false
  1014│     }
  1015│     return handleDrop(urls: urls)
      │            ▲
  1016│   }
  1017│

  6 0x0000000188b56018 -[NSTableView performDragOperation:] + 188 in AppKit
  7 0x00000001881bac44 NSCoreDragReceiveMessageProc + 452 in AppKit
  8 0x000000018b102284 CallReceiveMessageCollectionWithMessage + 116 in HIServices
  9 0x000000018b0fc084 DoMultipartDropMessage + 96 in HIServices
 10 0x000000018b0fbe44 DoDropMessage + 56 in HIServices
 11 0x000000018b0fa6b8 DragInApplication + 952 in HIServices
 12 0x000000018b1031a4 CoreDragStartDraggingAsync + 572 in HIServices
 13 0x00000001888764c8 -[NSCoreDragManager _dragUntilMouseUp:initialEvent:async:] + 1112 in AppKit
 14 0x0000000188875ff8 -[NSCoreDragManager _tryCatchDragUntilMouseUp:initialEvent:async:] + 32 in AppKit
 15 0x0000000183b04314 __CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__ + 36 in CoreFoundation
 16 0x0000000183b04210 __CFRunLoopDoObservers + 648 in CoreFoundation
 17 0x0000000183bd6204 _CFRunLoopRunSpecificWithOptions + 484 in CoreFoundation
 18 0x00000001908ef560 RunCurrentEventLoopInMode + 320 in HIToolbox
 19 0x00000001908f28bc ReceiveNextEventCommon + 488 in HIToolbox
 20 0x0000000190a7c14c _BlockUntilNextEventMatchingListInMode + 48 in HIToolbox
 21 0x00000001885e63d0 _DPSBlockUntilNextEventMatchingListInMode + 228 in AppKit
 22 0x0000000187f3a084 _DPSNextEvent + 576 in AppKit
 23 0x0000000188acf96c -[NSApplication(NSEventRouting) _nextEventMatchingEventMask:untilDate:inMode:dequeue:] + 688 in AppKit
 24 0x0000000188acf678 -[NSApplication(NSEventRouting) nextEventMatchingMask:untilDate:inMode:dequeue:] + 72 in AppKit
 25 0x0000000187f2d13c -[NSApplication run] + 368 in AppKit
 26 Commander_main + 164 in Commander at /Volumes/Femboy >_</Developer/Swift/commander/Sources/Commander/main.swift:7:5

     5│ app.delegate = delegate
     6│ app.setActivationPolicy(.regular)
     7│ app.run()
      │     ▲
     8│

...

Backtrace took 0.27s

zsh: trace trap  swift run
```

will fix this when I get the chance coz I need to move all the AppKit and switch to SwiftUI so