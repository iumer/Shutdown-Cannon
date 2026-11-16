import SwiftUI
import Cocoa

class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    @Published var timeRemaining: Int? = nil
    @Published var isCancelled: Bool = false
    var cancelAction: (() -> Void)?

    override init() {
        super.init()
        print("StatusBar: Initializing...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "⏲️"
            button.action = #selector(showPopover(_:))
            button.target = self
            print("StatusBar: Button created successfully")
        } else {
            print("StatusBar: ERROR - Could not create button")
        }
    }

    func startCountdown(minutes: Int) {
        print("StatusBar: Starting countdown for \(minutes) minutes")
        isCancelled = false
        timeRemaining = minutes * 60
        updateStatusTitle()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard let self = self else { return }
            if let remaining = self.timeRemaining, remaining > 0 {
                self.timeRemaining = remaining - 1
                self.updateStatusTitle()
                print("StatusBar: Time remaining: \(remaining) seconds")
            } else {
                self.timer?.invalidate()
                self.timeRemaining = nil
                self.updateStatusTitle()
                print("StatusBar: Countdown finished")
            }
        }
    }

    func cancelCountdown(completion: @escaping (Bool) -> Void) {
        print("StatusBar: Cancelling countdown")
        timer?.invalidate()
        timeRemaining = nil
        isCancelled = true
        updateStatusTitle()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let cancelCommand = """
            do shell script "
                sudo killall shutdown && \
                sudo pkill -f '/usr/sbin/shutdown' && \
                sudo kill -9 $(pgrep -f '/usr/sbin/shutdown') 2>/dev/null || true && \
                sudo pkill -f 'shutdown -h' && \
                sudo kill -9 $(pgrep -f 'shutdown -h') 2>/dev/null || true && \
                sudo killall -9 shutdown 2>/dev/null || true
            " with administrator privileges
            """
            
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", cancelCommand]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                // Verification
                let verifyTask = Process()
                verifyTask.launchPath = "/usr/bin/pgrep"
                verifyTask.arguments = ["-f", "/usr/sbin/shutdown"]
                let pipe = Pipe()
                verifyTask.standardOutput = pipe
                try verifyTask.run()
                verifyTask.waitUntilExit()
                
                DispatchQueue.main.async {
                    completion(pipe.fileHandleForReading.readDataToEndOfFile().isEmpty)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    private func updateStatusTitle() {
        if isCancelled {
            statusItem.button?.title = "❌"
            print("StatusBar: Updated to cancelled")
        } else if let remaining = timeRemaining {
            let mins = remaining / 60
            let secs = remaining % 60
            let title = String(format: "⏲️ %02d:%02d", mins, secs)
            statusItem.button?.title = title
            print("StatusBar: Updated to \(title)")
        } else {
            statusItem.button?.title = "⏲️"
            print("StatusBar: Updated to default")
        }
    }

    private var popover: NSPopover?
    @objc func showPopover(_ sender: Any?) {
        if popover == nil {
            let pop = NSPopover()
            pop.behavior = .transient
            pop.contentSize = NSSize(width: 200, height: 100)
            pop.contentViewController = NSHostingController(rootView: StatusPopoverView(controller: self))
            popover = pop
        }
        if let button = statusItem.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

struct StatusPopoverView: View {
    @ObservedObject var controller: StatusBarController
    var body: some View {
        VStack(spacing: 12) {
            if controller.isCancelled {
                Text("Shutdown Cancelled")
            } else if let remaining = controller.timeRemaining {
                Text("Time left: \(remaining / 60)m \(remaining % 60)s")
            } else {
                Text("No timer set")
            }
            Button("Cancel Shutdown") {
                controller.cancelAction?()
            }
            .disabled(controller.isCancelled || controller.timeRemaining == nil)
        }
        .padding()
        .frame(width: 180)
    }
}

@main
struct ShutdownTimerApp: App {
    @StateObject var statusBarController = StatusBarController()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(statusBarController)
                .onAppear {
                    self.statusBarController.cancelAction = {
                        self.statusBarController.cancelCountdown(completion: { success in
                            if !success {
                                let alert = NSAlert()
                                alert.messageText = "Cancellation Failed"
                                alert.informativeText = "Could not cancel shutdown. Try from main window or Terminal."
                                alert.runModal()
                            }
                        })
                    }
                }
        }
    }
}
