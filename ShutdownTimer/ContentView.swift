import SwiftUI
import Cocoa

func log(_ text: String) {
    let documents = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    let logFile = documents.appendingPathComponent("shutdown-timer-log.txt")
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
    let logEntry = "[\(timestamp)] \(text)\n"
    if let data = logEntry.data(using: .utf8) {
        do {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try data.write(to: logFile)
            }
        } catch {
            print("❌ Log write failed: \(error)")
        }
    }
}

struct CannonTimerPicker: View {
    let timeOptions: [(label: String, minutes: Int)] = [
        ("1 min", 1), ("5 min", 5), ("10 min", 10), ("20 min", 20), ("30 min", 30),
        ("1 hour", 60), ("1.5 hours", 90), ("2 hours", 120), ("2.5 hours", 150), ("3 hours", 180)
    ]
    @Binding var selectedIndex: Int?
    @State private var isHolding = false
    @State private var holdStart: Date? = nil
    @State private var holdAmount: CGFloat = 0
    @State private var ballPosition: CGPoint? = nil
    @State private var animating = false
    let lineLength: CGFloat = 320
    let cannonSize: CGFloat = 60
    let ballRadius: CGFloat = 16
    let lineY: CGFloat = 120
    let maxHoldSeconds: CGFloat = 2.0
    let minHoldSeconds: CGFloat = 0.1
    let maxTilt: CGFloat = -45

    var body: some View {
        ZStack(alignment: .leading) {
            Path { path in
                path.move(to: CGPoint(x: cannonSize + 20, y: lineY))
                path.addLine(to: CGPoint(x: cannonSize + 20 + lineLength, y: lineY))
            }
            .stroke(Color.gray, lineWidth: 4)

            ForEach(0..<timeOptions.count, id: \.self) { idx in
                let x = cannonSize + 20 + (CGFloat(idx) / CGFloat(timeOptions.count - 1)) * lineLength
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 2, height: 16)
                    Text(timeOptions[idx].label)
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .offset(y: idx % 2 == 0 ? 0 : 16)
                }
                .position(x: x, y: lineY + 24)
            }

            if let ballPos = ballPosition {
                Circle()
                    .fill(Color.purple)
                    .frame(width: ballRadius * 2, height: ballRadius * 2)
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    .position(ballPos)
                    .transition(.scale)
            }

            Text("Hold Me")
                .font(.headline)
                .foregroundColor(.secondary)
                .position(x: cannonSize/2, y: lineY - 60)

            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: cannonSize + 16, height: cannonSize + 16)
                    .shadow(radius: 6)
                Image("cannon_icon")
                    .resizable()
                    .frame(width: cannonSize, height: cannonSize)
                    .rotationEffect(.degrees(isHolding ? Double(maxTilt * holdAmount) : 0))
            }
            .position(x: cannonSize/2, y: lineY)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHolding && !animating {
                            isHolding = true
                            holdStart = Date()
                            holdAmount = 0
                            startHoldTimer()
                        }
                    }
                    .onEnded { _ in
                        if isHolding && !animating {
                            isHolding = false
                            let duration = CGFloat(Date().timeIntervalSince(holdStart ?? Date()))
                            let clamped = min(max(duration, minHoldSeconds), maxHoldSeconds)
                            let power = clamped / maxHoldSeconds
                            holdAmount = power
                            fireBallWithPower(power)
                        }
                    }
            )
            .animation(.easeOut(duration: 0.2), value: isHolding)
        }
        .frame(width: 460, height: 220)
        .padding(.bottom, 30)
    }

    func startHoldTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            if !isHolding { timer.invalidate(); return }
            let duration = CGFloat(Date().timeIntervalSince(holdStart ?? Date()))
            let clamped = min(max(duration, minHoldSeconds), maxHoldSeconds)
            holdAmount = clamped / maxHoldSeconds
        }
    }

    func fireBallWithPower(_ power: CGFloat) {
        animating = true
        let targetX = cannonSize + 20 + power * lineLength
        let idx = Int(round(power * CGFloat(timeOptions.count - 1)))
        selectedIndex = idx
        let start = CGPoint(x: cannonSize, y: lineY)
        let end = CGPoint(x: targetX, y: lineY)
        animateBall(from: start, to: end) {
            animating = false
        }
    }

    func animateBall(from start: CGPoint, to end: CGPoint, completion: @escaping () -> Void) {
        let mid = CGPoint(x: (start.x + end.x)/2, y: min(start.y, end.y) - 60)
        let animDuration = 0.6
        ballPosition = start
        withAnimation(.easeOut(duration: animDuration)) {
            ballPosition = mid
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + animDuration/2) {
            withAnimation(.easeIn(duration: animDuration/2)) {
                ballPosition = end
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + animDuration) {
            completion()
        }
    }
}

struct ContentView: View {
    @State private var selectedIndex: Int? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""
    let timeOptions: [(label: String, minutes: Int)] = [
        ("1 min", 1), ("5 min", 5), ("10 min", 10), ("20 min", 20), ("30 min", 30),
        ("1 hour", 60), ("1.5 hours", 90), ("2 hours", 120), ("2.5 hours", 150), ("3 hours", 180)
    ]
    @EnvironmentObject var statusBarController: StatusBarController

    var body: some View {
        VStack(spacing: 10) {
            Text("Shutdown Timer")
                .font(.title)
                .padding(.top, 10)
            CannonTimerPicker(selectedIndex: $selectedIndex)
                .padding(.bottom, 4)
            if let idx = selectedIndex {
                Text("\(timeOptions[idx].minutes) min(s)")
                    .font(.title2)
                    .bold()
            }
            Button("Set Timer") {
                scheduleShutdown()
            }
            .disabled(selectedIndex == nil)
            .padding(.top, 4)
            Button("Cancel Shutdown") {
                cancelShutdown()
            }
            .padding(.top, 2)
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.top, 2)
        }
        .frame(width: 340, height: 300)
        .padding(.bottom, 10)
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Shutdown Timer"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            statusBarController.cancelAction = {
                self.cancelShutdown()
            }
        }
    }

    func scheduleShutdown() {
        guard let idx = selectedIndex else {
            alertMessage = "Please select a time using the cannon."
            showingAlert = true
            return
        }
        let minutesInt = timeOptions[idx].minutes

        log("Starting countdown for \(minutesInt) minutes...")
        statusBarController.startCountdown(minutes: minutesInt)

        let shutdownCommand = "do shell script \"shutdown -h +\(minutesInt)\" with administrator privileges"
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", shutdownCommand]
        task.terminationHandler = { process in
            DispatchQueue.main.async {
                log("Shutdown command completed with status: \(process.terminationStatus)")
                log("✅ Shutdown scheduled in \(minutesInt) minutes.")
                self.alertMessage = "Shutdown scheduled in \(self.timeOptions[idx].label)."
                self.showingAlert = true
            }
        }
        do {
            try task.run()
            log("Shutdown command started...")
        } catch {
            log("❌ Failed to run shutdown task: \(error)")
            statusBarController.cancelCountdown { _ in
                self.alertMessage = "Failed to schedule shutdown. Please try again."
                self.showingAlert = true
            }
        }
    }

    func cancelShutdown() {
        log("Cancelling countdown...")
        statusBarController.cancelCountdown { success in
            DispatchQueue.main.async {
                if success {
                    log("✅ Shutdown successfully cancelled")
                    self.alertMessage = "Shutdown cancelled."
                } else {
                    log("❌ Failed to cancel shutdown")
                    self.alertMessage = """
                    Failed to fully cancel shutdown.

                    Try these Terminal commands:
                    sudo killall shutdown
                    sudo pkill -f '/usr/sbin/shutdown'
                    sudo kill -9 $(pgrep -f 'shutdown')
                    """
                }
                self.showingAlert = true
            }
        }
    }
}
