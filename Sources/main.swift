import Cocoa
import UserNotifications
import LocalAuthentication

final class BarButton: NSButton {
    private var hover = false
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds,
                               options: [.mouseEnteredAndExited, .activeAlways],
                               owner: self, userInfo: nil)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) { hover = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hover = false; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        if hover {
            NSColor.labelColor.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 3), xRadius: 7, yRadius: 7).fill()
        }
        super.draw(dirtyRect)
    }
}

final class DotView: NSView {
    var color: NSColor = .systemGreen { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    enum Mode: String { case phone, dex }

    var panel: NSPanel!
    var modeButton: NSButton!
    var allAppsButton: NSButton!
    var statusDot: DotView!
    var child: Process?
    var mode: Mode = .phone
    var displayID: Int?
    var tracking: Timer?
    var activity: NSObjectProtocol?
    var lastFrame: CGRect = .zero
    var logHandle: FileHandle?
    var pending = ""
    var isRetry = false
    var retryScheduled = false
    var manualAddress: String?
    var noDevice = false

    // Toolbar visibility / input preferences.
    var showToolbar = UserDefaults.standard.object(forKey: "showToolbar") as? Bool ?? true
    var toolbarItem: NSMenuItem!
    var absoluteMouse = UserDefaults.standard.object(forKey: "absoluteMouse") as? Bool ?? false
    var absoluteMouseItem: NSMenuItem!
    var disableAcceleration = UserDefaults.standard.object(forKey: "disableAcceleration") as? Bool ?? true
    var accelItem: NSMenuItem!
    var lowLatency = UserDefaults.standard.object(forKey: "lowLatency") as? Bool ?? false
    var lowLatencyItem: NSMenuItem!

    // Touch ID / password gate (Apple-style: authenticate before mirroring).
    var authenticated = false
    var requireAuth = UserDefaults.standard.object(forKey: "requireAuth") as? Bool ?? true
    var authItem: NSMenuItem!

    var mirrorNotifications = UserDefaults.standard.object(forKey: "mirrorNotifications") as? Bool ?? true
    var notifItem: NSMenuItem!

    // Keep the phone awake so the DeX taskbar does not collapse when the phone locks.
    var keepAwake = UserDefaults.standard.object(forKey: "keepAwake") as? Bool ?? true
    var keepAwakeItem: NSMenuItem!
    var autoUnlock = UserDefaults.standard.object(forKey: "autoUnlock") as? Bool ?? true
    var autoUnlockItem: NSMenuItem!
    var unlockTimer: Timer?
    var lastUnlockAttempt = Date.distantPast

    // iPhone-style notification mirroring.
    var notifTimer: Timer?
    var seenKeys = Set<String>()
    var initialPollDone = false
    let notifQueue = DispatchQueue(label: "MirrorDesk.notifications")

    // Everything the app needs is inside the bundle (official scrcpy macOS release).
    var resDir: String { Bundle.main.resourceURL?.path ?? "." }
    var scrcpyDir: String { resDir + "/scrcpy" }
    var adbPath: String { scrcpyDir + "/adb" }
    var scrcpyPath: String { resDir + "/Engine/MirrorDeskEngine.app/Contents/MacOS/mirrordesk-engine" }
    var serverPath: String { scrcpyDir + "/scrcpy-server" }
    var scriptPath: String { resDir + "/bin/mirrordesk" }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        openLog()
        buildMenu()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { self.log("notification permission: \(granted)") }
        }
        if CommandLine.arguments.contains("--dex") { mode = .dex }
        buildPanel()
        startWithAuth(mode: mode)
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.followWindow()
        }
        t.tolerance = 0.005
        RunLoop.main.add(t, forMode: .common)
        tracking = t
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical],
                                                         reason: "MirrorDesk toolbar tracking")
        log("MirrorDesk launched in \(mode.rawValue) mode")
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopChild()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        log("MirrorDesk terminated")
    }

    // MARK: - Menu

    func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About MirrorDesk",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit MirrorDesk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let mirrorItem = NSMenuItem()
        main.addItem(mirrorItem)
        let mirrorMenu = NSMenu(title: "Mirror")
        let phone = NSMenuItem(title: "Phone screen", action: #selector(menuPhone), keyEquivalent: "1")
        phone.target = self
        let dex = NSMenuItem(title: "DeX desktop", action: #selector(menuDex), keyEquivalent: "2")
        dex.target = self
        let stop = NSMenuItem(title: "Stop mirroring", action: #selector(menuStop), keyEquivalent: ".")
        stop.target = self
        let allApps = NSMenuItem(title: "All apps (DeX)", action: #selector(menuAllApps), keyEquivalent: "4")
        allApps.target = self
        let wallpaper = NSMenuItem(title: "DeX wallpaper…", action: #selector(menuWallpaper), keyEquivalent: "3")
        wallpaper.target = self
        let pair = NSMenuItem(title: "Pair phone…", action: #selector(menuPair), keyEquivalent: "p")
        pair.target = self
        let connect = NSMenuItem(title: "Connect to address…", action: #selector(menuConnect), keyEquivalent: "l")
        connect.target = self
        let pull = NSMenuItem(title: "Pull file from phone…", action: #selector(menuPull), keyEquivalent: "d")
        pull.target = self
        let choose = NSMenuItem(title: "Choose device…", action: #selector(menuChooseDevice), keyEquivalent: "")
        choose.target = self
        authItem = NSMenuItem(title: "Require Touch ID", action: #selector(toggleAuth), keyEquivalent: "")
        authItem.target = self
        authItem.state = requireAuth ? .on : .off
        notifItem = NSMenuItem(title: "Mirror notifications", action: #selector(toggleNotifications), keyEquivalent: "")
        notifItem.target = self
        notifItem.state = mirrorNotifications ? .on : .off
        keepAwakeItem = NSMenuItem(title: "Keep phone awake", action: #selector(toggleKeepAwake), keyEquivalent: "")
        keepAwakeItem.target = self
        keepAwakeItem.state = keepAwake ? .on : .off
        keepAwakeItem.toolTip = "Sets the phone's screen timeout to never and keeps it awake while mirroring; restores on stop."
        autoUnlockItem = NSMenuItem(title: "Auto-unlock when phone locks", action: #selector(toggleAutoUnlock), keyEquivalent: "")
        autoUnlockItem.target = self
        autoUnlockItem.state = autoUnlock ? .on : .off
        autoUnlockItem.toolTip = "Wakes the phone and dismisses its lock screen when it locks, so the full DeX taskbar stays visible. Uses more battery."

        let inputItem = NSMenuItem()
        let inputMenu = NSMenu(title: "Input")
        let scrollItem = NSMenuItem(title: "Scroll speed", action: nil, keyEquivalent: "")
        let scrollMenu = NSMenu(title: "Scroll speed")
        for (title, value) in [("Slowest (0)", 0), ("Slow (2)", 2), ("Normal (5)", 5), ("Fast (8)", 8), ("Fastest (10)", 10)] {
            let item = NSMenuItem(title: title, action: #selector(setScrollSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            scrollMenu.addItem(item)
        }
        scrollItem.submenu = scrollMenu
        inputMenu.addItem(scrollItem)

        accelItem = NSMenuItem(title: "Disable pointer acceleration", action: #selector(toggleAccel), keyEquivalent: "")
        accelItem.target = self
        accelItem.state = disableAcceleration ? .on : .off
        inputMenu.addItem(accelItem)

        let pointerItem = NSMenuItem(title: "Pointer speed", action: nil, keyEquivalent: "")
        let pointerMenu = NSMenu(title: "Pointer speed")
        for (title, value) in [("Slow (0)", 0), ("Medium (3)", 3), ("Fast (5)", 5), ("Fastest (7)", 7)] {
            let item = NSMenuItem(title: title, action: #selector(setPointerSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            pointerMenu.addItem(item)
        }
        pointerItem.submenu = pointerMenu
        inputMenu.addItem(pointerItem)

        lowLatencyItem = NSMenuItem(title: "Low latency mode", action: #selector(toggleLowLatency), keyEquivalent: "")
        lowLatencyItem.target = self
        lowLatencyItem.state = lowLatency ? .on : .off
        lowLatencyItem.toolTip = "Uses a 0 ms video buffer and 16M bitrate: more responsive, but may drop more frames."
        inputMenu.addItem(lowLatencyItem)

        absoluteMouseItem = NSMenuItem(title: "Absolute mouse (no capture)", action: #selector(toggleAbsoluteMouse), keyEquivalent: "")
        absoluteMouseItem.target = self
        absoluteMouseItem.state = absoluteMouse ? .on : .off
        absoluteMouseItem.toolTip = "Uses absolute coordinates and the local Mac cursor; no pointer capture."
        inputMenu.addItem(absoluteMouseItem)

        inputMenu.addItem(NSMenuItem.separator())
        let mouseHelp = NSMenuItem(title: "Mouse stuck? Press ⌥ to release", action: #selector(showMouseHelp), keyEquivalent: "")
        mouseHelp.target = self
        inputMenu.addItem(mouseHelp)
        inputItem.submenu = inputMenu

        toolbarItem = NSMenuItem(title: "Show title-bar toolbar", action: #selector(toggleToolbar), keyEquivalent: "")
        toolbarItem.target = self
        toolbarItem.state = showToolbar ? .on : .off

        mirrorMenu.addItem(phone)
        mirrorMenu.addItem(dex)
        mirrorMenu.addItem(NSMenuItem.separator())
        mirrorMenu.addItem(allApps)
        mirrorMenu.addItem(wallpaper)
        mirrorMenu.addItem(NSMenuItem.separator())
        mirrorMenu.addItem(pair)
        mirrorMenu.addItem(connect)
        mirrorMenu.addItem(pull)
        mirrorMenu.addItem(choose)
        mirrorMenu.addItem(NSMenuItem.separator())
        mirrorMenu.addItem(authItem)
        mirrorMenu.addItem(notifItem)
        mirrorMenu.addItem(keepAwakeItem)
        mirrorMenu.addItem(autoUnlockItem)
        mirrorMenu.addItem(NSMenuItem.separator())
        mirrorMenu.addItem(inputItem)
        mirrorMenu.addItem(toolbarItem)
        mirrorMenu.addItem(NSMenuItem.separator())
        mirrorMenu.addItem(stop)
        mirrorItem.submenu = mirrorMenu

        NSApp.mainMenu = main
    }

    @objc func menuPhone() { if mode != .phone { startWithAuth(mode: .phone) } }
    @objc func menuDex() { if mode != .dex { startWithAuth(mode: .dex) } }
    @objc func menuStop() { stopChild(); NSApp.terminate(nil) }

    @objc func setScrollSpeed(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Int else { return }
        let serial = currentSerial()
        var args: [String] = []
        if !serial.isEmpty { args += ["-s", serial] }
        args += ["shell", "settings", "put", "system", "mouse_scrolling_speed", "\(value)"]
        _ = runAdb(args)
        log("mouse_scrolling_speed=\(value)")
    }

    @objc func toggleAccel() {
        disableAcceleration.toggle()
        UserDefaults.standard.set(disableAcceleration, forKey: "disableAcceleration")
        accelItem.state = disableAcceleration ? .on : .off
        let serial = currentSerial()
        var args: [String] = []
        if !serial.isEmpty { args += ["-s", serial] }
        args += ["shell", "settings", "put", "system", "mouse_pointer_acceleration", disableAcceleration ? "1" : "0"]
        _ = runAdb(args)
        log("mouse_pointer_acceleration=\(disableAcceleration ? 1 : 0) (1=off)")
    }

    @objc func setPointerSpeed(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Int else { return }
        let serial = currentSerial()
        var args: [String] = []
        if !serial.isEmpty { args += ["-s", serial] }
        args += ["shell", "settings", "put", "system", "pointer_speed", "\(value)"]
        _ = runAdb(args)
        log("pointer_speed=\(value)")
    }

    @objc func toggleAbsoluteMouse() {
        absoluteMouse.toggle()
        UserDefaults.standard.set(absoluteMouse, forKey: "absoluteMouse")
        absoluteMouseItem.state = absoluteMouse ? .on : .off
        log("absolute mouse: \(absoluteMouse)")
        if child != nil { start(mode: mode) }
    }

    @objc func toggleLowLatency() {
        lowLatency.toggle()
        UserDefaults.standard.set(lowLatency, forKey: "lowLatency")
        lowLatencyItem.state = lowLatency ? .on : .off
        log("low latency: \(lowLatency)")
        if child != nil { start(mode: mode) }
    }

    @objc func toggleToolbar() {
        showToolbar.toggle()
        UserDefaults.standard.set(showToolbar, forKey: "showToolbar")
        toolbarItem.state = showToolbar ? .on : .off
        if showToolbar {
            followWindow()
        } else {
            panel.orderOut(nil)
        }
    }

    @objc func showMouseHelp() {
        let a = NSAlert()
        a.messageText = "Mouse stuck in the DeX window?"
        a.informativeText = "Press ⌥ (Option) once to release the mouse back to the Mac; press ⌥ again to capture it. If you prefer no capture at all, turn on Mirror → Input → Absolute mouse (no capture)."
        a.runModal()
    }

    @objc func menuAllApps() {
        guard mode == .dex else { return }
        goAllApps()
    }

    @objc func menuWallpaper() {
        guard mode == .dex, let d = displayID else { return }
        let serial = currentSerial()
        var args: [String] = []
        if !serial.isEmpty { args += ["-s", serial] }
        args += ["shell", "am", "start", "--display", "\(d)", "-n",
                 "com.android.wallpaper.livepicker/.LiveWallpaperActivity"]
        _ = runAdb(args)
        log("opened wallpaper picker on display \(d)")
    }

    @objc func menuPair() {
        let a = NSAlert()
        a.messageText = "Pair with your phone"
        a.informativeText = "On the phone: Settings → Developer options → Wireless debugging → Pair device with pairing code. Type the IP:PORT and the 6-digit code shown in that dialog."
        a.addButton(withTitle: "Pair")
        a.addButton(withTitle: "Cancel")

        let ipField = NSTextField(frame: NSRect(x: 0, y: 44, width: 280, height: 24))
        ipField.placeholderString = "192.168.1.23:37123 (pairing port)"
        let codeField = NSTextField(frame: NSRect(x: 0, y: 8, width: 280, height: 24))
        codeField.placeholderString = "6-digit code"
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 76))
        box.addSubview(ipField)
        box.addSubview(codeField)
        a.accessoryView = box

        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let ip = ipField.stringValue.trimmingCharacters(in: .whitespaces)
        let code = codeField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !ip.isEmpty, !code.isEmpty else { return }

        let ok = runAdb(["pair", ip, code])
        let done = NSAlert()
        done.messageText = ok ? "Paired" : "Pairing failed"
        done.informativeText = ok ? "Starting mirroring…" : "Check the pairing IP:PORT and code, and make sure Wireless debugging is on."
        done.runModal()
        if ok {
            manualAddress = nil
            start(mode: mode)
        }
    }

    @objc func menuConnect() {
        let a = NSAlert()
        a.messageText = "Connect to address"
        a.informativeText = "Enter the IP:PORT shown on the phone's Wireless debugging page."
        a.addButton(withTitle: "Connect")
        a.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "192.168.1.23:37123"
        a.accessoryView = field

        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let addr = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !addr.isEmpty else { return }
        manualAddress = addr
        startWithAuth(mode: mode)
    }

    @objc func menuPull() {
        let a = NSAlert()
        a.messageText = "Pull file/folder from phone"
        a.informativeText = "Absolute path on the phone, e.g. /sdcard/DCIM/Camera/IMG_0001.jpg or /sdcard/Download"
        a.addButton(withTitle: "Pull")
        a.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "/sdcard/Download"
        a.accessoryView = field

        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let path = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }

        let destDir = NSHomeDirectory() + "/Downloads/MirrorDesk"
        try? FileManager.default.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        let serial = activeSerial

        let p = Process()
        p.executableURL = URL(fileURLWithPath: adbPath)
        var args: [String] = []
        if !serial.isEmpty { args += ["-s", serial] }
        args += ["pull", path, destDir]
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        p.terminationHandler = { [weak self] proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                self?.log("pull \(path): \(out.trimmingCharacters(in: .whitespacesAndNewlines))")
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: destDir)])
            }
        }
        do { try p.run() } catch { alert("adb pull failed to start: \(error.localizedDescription)") }
    }

    @objc func menuChooseDevice() {
        let out = runAdbOutput(["devices"])
        let serials: [String] = out.split(separator: "\n").dropFirst().compactMap { line in
            let parts = line.split(separator: "\t")
            guard parts.count >= 2, parts[1].hasPrefix("device") else { return nil }
            return String(parts[0])
        }
        guard !serials.isEmpty else {
            alert("No adb devices connected.")
            return
        }
        let a = NSAlert()
        a.messageText = "Choose device"
        a.addButton(withTitle: "Use")
        a.addButton(withTitle: "Cancel")
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 26), pullsDown: false)
        popup.addItems(withTitles: serials)
        a.accessoryView = popup
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        manualAddress = popup.titleOfSelectedItem
        startWithAuth(mode: mode)
    }

    @objc func toggleAuth() {
        requireAuth.toggle()
        UserDefaults.standard.set(requireAuth, forKey: "requireAuth")
        authItem.state = requireAuth ? .on : .off
        authenticated = false
        log("requireAuth = \(requireAuth)")
    }

    @objc func toggleNotifications() {
        mirrorNotifications.toggle()
        UserDefaults.standard.set(mirrorNotifications, forKey: "mirrorNotifications")
        notifItem.state = mirrorNotifications ? .on : .off
        if mirrorNotifications {
            startNotificationPolling()
        } else {
            stopNotificationPolling()
        }
        log("mirrorNotifications = \(mirrorNotifications)")
    }

    @objc func toggleKeepAwake() {
        keepAwake.toggle()
        UserDefaults.standard.set(keepAwake, forKey: "keepAwake")
        keepAwakeItem.state = keepAwake ? .on : .off
        if keepAwake {
            applyKeepAwake()
        } else {
            restoreKeepAwake()
        }
        log("keepAwake = \(keepAwake)")
    }

    @objc func toggleAutoUnlock() {
        autoUnlock.toggle()
        UserDefaults.standard.set(autoUnlock, forKey: "autoUnlock")
        autoUnlockItem.state = autoUnlock ? .on : .off
        if autoUnlock {
            startAutoUnlock()
        } else {
            unlockTimer?.invalidate()
            unlockTimer = nil
        }
        log("autoUnlock = \(autoUnlock)")
    }

    func startWithAuth(mode: Mode) {
        if !requireAuth || authenticated {
            authenticated = true
            start(mode: mode)
            return
        }
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            log("no device authentication: \(err?.localizedDescription ?? "unavailable")")
            authenticated = true
            start(mode: mode)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        ctx.evaluatePolicy(.deviceOwnerAuthentication,
                           localizedReason: "Unlock your phone on this Mac") { ok, error in
            DispatchQueue.main.async {
                if ok {
                    self.authenticated = true
                    self.log("authenticated")
                    self.start(mode: mode)
                } else {
                    self.log("authentication cancelled: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }

    // MARK: - Panel

    func buildPanel() {
        let w: CGFloat = 148, h: CGFloat = 26
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = content

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])

        stack.addArrangedSubview(button("chevron.backward", "Back  (⌥B / right-click)", #selector(goBack)))
        stack.addArrangedSubview(button("house", "Home  (⌥H)", #selector(goHome)))
        stack.addArrangedSubview(button("square.on.square", "Recent apps  (⌥S)", #selector(goRecents)))

        allAppsButton = button("square.grid.2x2", "All apps (DeX)", #selector(goAllApps))
        allAppsButton.isHidden = (mode != .dex)
        stack.addArrangedSubview(allAppsButton)

        modeButton = button(mode == .dex ? "iphone" : "desktopcomputer", "Switch mode", #selector(toggleMode))
        stack.addArrangedSubview(modeButton)

        panel.orderOut(nil)
    }

    func button(_ symbol: String, _ tip: String, _ action: Selector) -> BarButton {
        let b = BarButton()
        b.isBordered = false
        let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)?
            .withSymbolConfiguration(cfg)
        b.imagePosition = .imageOnly
        b.contentTintColor = .labelColor
        b.target = self
        b.action = action
        b.toolTip = tip
        b.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: 26),
            b.heightAnchor.constraint(equalToConstant: 24)
        ])
        return b
    }

    func updateModeButton() {
        let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        modeButton?.image = NSImage(systemSymbolName: mode == .dex ? "iphone" : "desktopcomputer",
                                    accessibilityDescription: "Switch mode")?
            .withSymbolConfiguration(cfg)
        modeButton?.toolTip = mode == .dex ? "Switch to phone screen" : "Switch to DeX desktop"
        allAppsButton?.isHidden = (mode != .dex)
    }

    // MARK: - Mirroring

    func start(mode: Mode, isRetry retry: Bool = false) {
        stopChild()
        self.mode = mode
        self.isRetry = retry
        noDevice = false
        displayID = nil
        lastFrame = .zero
        updateModeButton()

        let script = scriptPath
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = scrcpyDir + ":/usr/bin:/bin:/usr/sbin:/sbin"
        env["ADB"] = adbPath
        env["SCRCPY"] = scrcpyPath
        env["SCRCPY_SERVER_PATH"] = serverPath
        env["WINDOW_TITLE"] = (mode == .dex) ? "DeX desktop" : "Phone screen"
        env["VIDEO_BUFFER"] = lowLatency ? "0" : "100"
        env["VIDEO_BIT_RATE"] = lowLatency ? "16M" : "24M"
        env["SDL_MAC_BACKGROUND_APP"] = "1"

        var args: [String] = []
        if let addr = manualAddress { args.append(addr) }
        if mode == .dex {
            args.append("--new-display=1920x1080")
            args.append(absoluteMouse ? "--mouse=sdk" : "-M")
        }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: script)
        p.arguments = args
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.handleOutput(s) }
        }
        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self, self.child === proc else { return }
                self.child = nil
                self.stopNotificationPolling()
                self.panel.orderOut(nil)
                if self.noDevice {
                    self.noDevice = false
                    return
                }
                if self.retryScheduled { return }
                NSApp.terminate(nil)
            }
        }
        do {
            try p.run()
        } catch {
            alert("Cannot start \(script):\n\(error.localizedDescription)")
            NSApp.terminate(nil)
            return
        }
        child = p
        log("started \(mode.rawValue) mode, pid \(p.processIdentifier)")
        startNotificationPolling()
        if mode == .phone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.applyKeepAwake()
                self?.startAutoUnlock()
            }
        }
    }

    func stopChild() {
        stopNotificationPolling()
        unlockTimer?.invalidate()
        unlockTimer = nil
        restoreKeepAwake()
        if let c = child {
            child = nil
            if c.isRunning { c.terminate() }
        }
    }

    func handleOutput(_ s: String) {
        pending += s
        if pending.contains("No device found") {
            log("no device found")
            noDevice = true
            alert("Phone not reachable.\n\n1. On the phone, enable Wireless debugging.\n2. New Mac? Use Mirror → Pair phone… first (6-digit code).\n3. If discovery fails, use Mirror → Connect to address… with the IP:PORT from Wireless debugging.")
            return
        }
        while let nl = pending.firstIndex(of: "\n") {
            let line = String(pending[..<nl])
            pending = String(pending[pending.index(after: nl)...])
            log(line.trimmingCharacters(in: .whitespaces))
            if line.contains("Server connection failed"), !isRetry {
                isRetry = true
                retryScheduled = true
                log("scrcpy server failed — restarting adb and retrying once")
                _ = runAdb(["kill-server"])
                _ = runAdb(["start-server"])
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self else { return }
                    self.retryScheduled = false
                    self.start(mode: self.mode, isRetry: true)
                }
                return
            }
            if mode == .dex, displayID == nil, line.contains("New display"), let r = line.range(of: "(id=") {
                let digits = line[r.upperBound...].prefix { $0.isNumber }
                if let n = Int(digits) {
                    displayID = n
                    log("DeX virtual display id \(n)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                        self?.bringDeXHome()
                    }
                }
            }
        }
    }

    func bringDeXHome() {
        guard let d = displayID else { return }
        let serial = currentSerial()
        var args: [String] = []
        if !serial.isEmpty { args += ["-s", serial] }
        args += ["shell", "am", "start", "--display", "\(d)", "-n",
                 "com.sec.android.app.launcher/com.honeyspace.dexservice.SecondaryLauncher"]
        _ = runAdb(args)
        log("brought DeX home to front on display \(d)")
        applyKeepAwake()
        startAutoUnlock()
    }

    // MARK: - Keep awake / auto-unlock

    func applyKeepAwake() {
        guard keepAwake else { return }
        let serial = activeSerial
        guard !serial.isEmpty else { return }
        let d = UserDefaults.standard
        if d.string(forKey: "savedScreenTimeout") == nil {
            let t = runAdbOutput(["-s", serial, "shell", "settings", "get", "system", "screen_off_timeout"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { d.set(t, forKey: "savedScreenTimeout") }
            let s = runAdbOutput(["-s", serial, "shell", "settings", "get", "global", "stay_on_while_plugged_in"])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { d.set(s, forKey: "savedStayOn") }
        }
        _ = runAdb(["-s", serial, "shell", "settings", "put", "system", "screen_off_timeout", "2147483647"])
        _ = runAdb(["-s", serial, "shell", "svc", "power", "stayon", "true"])
        log("keep awake applied")
    }

    func restoreKeepAwake() {
        let serial = activeSerial
        guard !serial.isEmpty else { return }
        let d = UserDefaults.standard
        if let t = d.string(forKey: "savedScreenTimeout") {
            _ = runAdb(["-s", serial, "shell", "settings", "put", "system", "screen_off_timeout", t])
        }
        if let s = d.string(forKey: "savedStayOn") {
            _ = runAdb(["-s", serial, "shell", "settings", "put", "global", "stay_on_while_plugged_in", s])
        }
        d.removeObject(forKey: "savedScreenTimeout")
        d.removeObject(forKey: "savedStayOn")
        log("keep awake restored")
    }

    func startAutoUnlock() {
        unlockTimer?.invalidate()
        guard autoUnlock else { return }
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.checkAutoUnlock()
        }
        RunLoop.main.add(t, forMode: .common)
        unlockTimer = t
        t.fire()
    }

    func checkAutoUnlock() {
        guard autoUnlock else { return }
        let serial = activeSerial
        guard !serial.isEmpty else { return }
        let out = runAdbOutput(["-s", serial, "shell", "dumpsys", "window", "policy"])
        guard out.contains("KeyguardServiceDelegate"), out.contains("showing=true") else { return }
        guard Date().timeIntervalSince(lastUnlockAttempt) > 5 else { return }
        lastUnlockAttempt = Date()
        _ = runAdb(["-s", serial, "shell", "input", "keyevent", "224"])
        _ = runAdb(["-s", serial, "shell", "wm", "dismiss-keyguard"])
        log("auto-unlocked keyguard")
    }

    // MARK: - Toolbar actions

    @objc func goBack() { key(4) }
    @objc func goHome() { key(3) }
    @objc func goRecents() { key(187) }
    @objc func goAllApps() { key(284) }

    @objc func toggleMode() {
        startWithAuth(mode: mode == .dex ? .phone : .dex)
    }

    func key(_ code: Int) {
        let serial = currentSerial()
        var args: [String] = []
        if !serial.isEmpty { args += ["-s", serial] }
        args += ["shell", "input"]
        if mode == .dex, let d = displayID { args += ["-d", "\(d)"] }
        args += ["keyevent", "\(code)"]
        if !runAdb(args) {
            var fallback = ["shell", "input"]
            if mode == .dex, let d = displayID { fallback += ["-d", "\(d)"] }
            fallback += ["keyevent", "\(code)"]
            _ = runAdb(fallback)
        }
    }

    var activeSerial: String { manualAddress ?? currentSerial() }

    func runAdbOutput(_ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: adbPath)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    @discardableResult
    func runAdb(_ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: adbPath)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    func currentSerial() -> String {
        let path = NSHomeDirectory() + "/.local/share/mirrordesk/state"
        guard let txt = try? String(contentsOfFile: path, encoding: .utf8) else { return "" }
        for line in txt.split(separator: "\n") where line.hasPrefix("serial=") {
            return String(line.dropFirst("serial=".count))
        }
        return ""
    }

    // MARK: - Notification mirroring (iPhone-style)

    func startNotificationPolling() {
        guard mirrorNotifications else { return }
        notifTimer?.invalidate()
        initialPollDone = false
        seenKeys = []
        notifTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.pollNotifications()
        }
        notifTimer?.fire()
    }

    func stopNotificationPolling() {
        notifTimer?.invalidate()
        notifTimer = nil
        initialPollDone = false
        seenKeys = []
    }

    func pollNotifications() {
        guard child?.isRunning == true else { return }
        let serial = activeSerial
        guard !serial.isEmpty else { return }

        notifQueue.async { [weak self] in
            guard let self else { return }
            let list = self.runAdbOutput(["-s", serial, "shell", "cmd", "notification", "list"])
            let keys = list.split(separator: "\n")
                .map(String.init)
                .filter { !$0.isEmpty && !$0.contains("SUMMARY") }
            let current = Set(keys)

            if !self.initialPollDone {
                self.initialPollDone = true
                self.seenKeys = current
                return
            }

            let newKeys = current.subtracting(self.seenKeys)
            self.seenKeys = current

            for key in newKeys {
                let parts = key.split(separator: "|")
                guard parts.count >= 2 else { continue }
                let pkg = String(parts[1])
                if pkg == "android" || pkg == "com.android.systemui" || pkg == "com.android.shell" { continue }
                let dump = self.runAdbOutput(["-s", serial, "shell", "cmd", "notification", "get", "\"\(key)\""])
                let (title, text) = self.parseNotification(dump)
                if title.isEmpty && (text.isEmpty || text == "null") { continue }
                DispatchQueue.main.async {
                    self.postNotification(pkg: pkg, title: title, text: text)
                }
            }
        }
    }

    func parseNotification(_ dump: String) -> (String, String) {
        var title = "", text = "", big = ""
        for raw in dump.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("android.title=String (") { title = stringValue(line) }
            else if line.hasPrefix("android.text=String (") { text = stringValue(line) }
            else if line.hasPrefix("android.bigText=String (") { big = stringValue(line) }
            else if line.hasPrefix("tickerText="), text.isEmpty {
                text = String(line.dropFirst("tickerText=".count))
            }
        }
        if !big.isEmpty && (text.isEmpty || big.count > text.count) { text = big }
        if title == "null" { title = "" }
        if text == "null" { text = "" }
        return (title, text)
    }

    func stringValue(_ line: String) -> String {
        guard let r = line.range(of: "String (") else { return "" }
        var s = String(line[r.upperBound...])
        if s.hasSuffix(")") { s.removeLast() }
        return s
    }

    func appName(_ pkg: String) -> String {
        let names: [String: String] = [
            "com.tencent.mm": "WeChat",
            "com.eg.android.AlipayGphone": "Alipay",
            "com.google.android.gm": "Gmail",
            "com.android.chrome": "Chrome",
            "com.google.android.apps.messaging": "Messages",
            "com.samsung.android.messaging": "Messages",
            "com.zhiliaoapp.musically": "TikTok",
            "com.ss.android.ugc.aweme": "Douyin",
            "com.bilibili.app.in": "Bilibili",
            "org.telegram.messenger": "Telegram",
            "com.discord": "Discord",
            "com.google.android.youtube": "YouTube",
            "com.netflix.mediaclient": "Netflix",
            "com.spotify.music": "Spotify",
            "com.instagram.android": "Instagram",
            "com.facebook.katana": "Facebook",
            "com.whatsapp": "WhatsApp",
            "com.twitter.android": "X",
            "com.d2l.brightspace.student.android": "Brightspace",
            "com.samsung.android.calendar": "Calendar",
            "com.sec.android.app.clockpackage": "Clock",
            "com.microsoft.teams": "Teams",
            "com.linkedin.android": "LinkedIn"
        ]
        if let n = names[pkg] { return n }
        let parts = pkg.split(separator: ".")
        return parts.count >= 2 ? String(parts.suffix(2).joined(separator: ".")) : pkg
    }

    func postNotification(pkg: String, title: String, text: String) {
        let content = UNMutableNotificationContent()
        content.title = appName(pkg)
        content.subtitle = title
        content.body = text
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { [weak self] error in
            if let error {
                self?.log("notification add error: \(error.localizedDescription)")
            } else {
                self?.log("posted notification from \(pkg): \(title) — \(text)")
            }
        }
    }

    // MARK: - Window following

    func followWindow() {
        guard let pid = child?.processIdentifier, child?.isRunning == true else { return }
        guard let info = windowInfo(pid: pid) else { return }
        updatePanelVisibility(pid: pid, onScreen: info.onScreen)
        let f = info.frame
        guard !f.equalTo(lastFrame) else { return }
        lastFrame = f
        let mainScreen = NSScreen.screens.first ?? NSScreen.main!
        let mainHeight = mainScreen.frame.height
        let nsTop = mainHeight - (f.origin.y + f.height)
        let windowRect = NSRect(x: f.origin.x, y: nsTop, width: f.width, height: f.height)
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(windowRect) }) ?? mainScreen
        let sf = screen.frame
        let w = panel.frame.width, h = panel.frame.height
        var x = f.maxX - w - 10
        var y = nsTop + f.height - h - 2
        x = max(sf.minX + 8, min(x, sf.maxX - w - 8))
        y = max(sf.minY + 8, min(y, sf.maxY - h - 8))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func updatePanelVisibility(pid: pid_t, onScreen: Bool) {
        guard showToolbar else {
            if panel.isVisible { panel.orderOut(nil) }
            return
        }
        let active = NSRunningApplication(processIdentifier: pid)?.isActive ?? false
        if onScreen && (active || NSApp.isActive) {
            if !panel.isVisible { panel.orderFront(nil) }
        } else {
            if panel.isVisible { panel.orderOut(nil) }
        }
    }

    func windowInfo(pid: pid_t) -> (frame: CGRect, onScreen: Bool)? {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        var best: (CGRect, Bool)?
        var bestArea: CGFloat = 0
        for w in list {
            guard let owner = w[kCGWindowOwnerPID as String] as? Int, owner == Int(pid) else { continue }
            guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let b = w[kCGWindowBounds as String] as? [String: NSNumber],
                  let x = b["X"]?.doubleValue, let y = b["Y"]?.doubleValue,
                  let width = b["Width"]?.doubleValue, let height = b["Height"]?.doubleValue,
                  width > 200, height > 200 else { continue }
            let area = width * height
            if area > bestArea {
                bestArea = area
                let onScreen = (w[kCGWindowIsOnscreen as String] as? Bool) ?? false
                best = (CGRect(x: x, y: y, width: width, height: height), onScreen)
            }
        }
        return best
    }

    // MARK: - Misc

    func alert(_ message: String) {
        let a = NSAlert()
        a.messageText = "MirrorDesk"
        a.informativeText = message
        a.runModal()
    }

    func openLog() {
        let path = NSHomeDirectory() + "/Library/Logs/MirrorDesk.log"
        FileManager.default.createFile(atPath: path, contents: nil)
        logHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path))
        logHandle?.seekToEndOfFile()
    }

    func log(_ s: String) {
        guard let d = "[\(Date())] \(s)\n".data(using: .utf8) else { return }
        logHandle?.write(d)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
