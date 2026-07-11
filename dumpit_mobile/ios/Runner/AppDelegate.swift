import Flutter
import UIKit
import EventKit
import AVFoundation

class BinauralPlayer {
  private let audioEngine = AVAudioEngine()
  private var sourceNode: AVAudioSourceNode?
  private var isPlaying = false
  
  func start() {
    guard !isPlaying else { return }
    let sampleRate = 44100.0
    var phaseLeft = 0.0
    var phaseRight = 0.0
    let freqLeft = 400.0
    let freqRight = 408.0 // 8Hz Alpha 波差频，可辅助 ADHD 深度专注
    
    sourceNode = AVAudioSourceNode { (_, _, frameCount, audioBufferList) -> OSStatus in
      let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
      guard let leftBuffer = abl[0].mData?.assumingMemoryBound(to: Float.self),
            let rightBuffer = abl[1].mData?.assumingMemoryBound(to: Float.self) else {
        return noErr
      }
      
      for frame in 0..<Int(frameCount) {
        let sampleLeft = sin(phaseLeft) * 0.12 // 柔和的音量大小
        let sampleRight = sin(phaseRight) * 0.12
        
        leftBuffer[frame] = Float(sampleLeft)
        rightBuffer[frame] = Float(sampleRight)
        
        phaseLeft += 2.0 * .pi * freqLeft / sampleRate
        phaseRight += 2.0 * .pi * freqRight / sampleRate
      }
      return noErr
    }
    
    guard let node = sourceNode else { return }
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
    audioEngine.attach(node)
    audioEngine.connect(node, to: audioEngine.outputNode, format: format)
    
    do {
      try audioEngine.start()
      isPlaying = true
    } catch {
      // Audio engine start failed
    }
  }
  
  func stop() {
    guard isPlaying else { return }
    audioEngine.stop()
    if let node = sourceNode {
      audioEngine.detach(node)
    }
    sourceNode = nil
    isPlaying = false
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var eventStore: EKEventStore?
  private var launchUrl: String?
  private let focusPlayer = BinauralPlayer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return result
    }
    let syncChannel = FlutterMethodChannel(name: "com.brainvent.app/device_sync",
                                              binaryMessenger: controller.binaryMessenger)
    
    syncChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      if call.method == "syncReminders" {
        guard let args = call.arguments as? [String: Any],
              let items = args["items"] as? [String] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing items arguments", details: nil))
          return
        }
        self.syncRemindersToiOS(items: items, result: result)
      } else if call.method == "getLaunchUrl" {
        result(self.launchUrl)
        self.launchUrl = nil
      } else if call.method == "toggleFocusSound" {
        guard let args = call.arguments as? [String: Any],
              let play = args["play"] as? Bool else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing play argument", details: nil))
          return
        }
        if play {
          self.focusPlayer.start()
        } else {
          self.focusPlayer.stop()
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    return result
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    self.launchUrl = url.absoluteString
    NotificationCenter.default.post(name: Notification.Name("BrainVentLaunchUrlNotification"), object: url.absoluteString)
    return super.application(app, open: url, options: options)
  }

  private func syncRemindersToiOS(items: [String], result: @escaping FlutterResult) {
    let store = EKEventStore()
    self.eventStore = store
    
    // 请求权限
    store.requestAccess(to: .reminder) { (granted, error) in
      if let error = error {
        result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
        return
      }
      
      guard granted else {
        result(FlutterError(code: "PERMISSION_DENIED", message: "Reminder access denied", details: nil))
        return
      }
      
      // 安全获取或回退提醒日历，防止 nil 导致解包崩溃
      guard let calendar = store.defaultCalendarForNewReminders() ?? store.calendars(for: .reminder).first else {
        result(FlutterError(code: "CALENDAR_ERROR", message: "No default or existing reminder calendar found", details: nil))
        return
      }
      
      var successCount = 0
      for item in items {
        let reminder = EKReminder(eventStore: store)
        reminder.title = item
        reminder.calendar = calendar
        
        do {
          try store.save(reminder, commit: false)
          successCount += 1
        } catch {
          // Ignore individual errors
        }
      }
      
      do {
        try store.commit()
        DispatchQueue.main.async {
          result(successCount > 0)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "SAVE_ERROR", message: "Failed to save reminders", details: nil))
        }
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
