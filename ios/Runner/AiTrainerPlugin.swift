import Foundation
import Flutter
import UIKit
import AVFoundation
import MediaPipeTasksVision

/// iOS mirror of the Android native bridge. Channel names and event schema
/// match docs/INTERNAL_APIS.md exactly.
///
/// STATUS: IN_PROGRESS — source prepared only. Cannot be compiled, signed or
/// device-tested on Linux/Windows. On macOS, add MediaPipeTasksVision via SPM
/// (https://github.com/google-ai-edge/mediapipe-ios) before building.
final class AiTrainerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, AVCaptureVideoDataOutputSampleBufferDelegate {

  private let channelName = "ai_gym_trainer/camera"
  private let eventName = "ai_gym_trainer/pose"
  private let viewType = "ai_gym_trainer/camera_view"

  private var eventSink: FlutterEventSink?
  private var captureSession: AVCaptureSession?
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var landmarker: PoseLandmarker?
  private var timestamp: UInt64 = 0
  private let sessionQueue = DispatchQueue(label: "ai.gym.trainer.camera")
  private var running = false
  private var lastInferenceMs: Double = 0

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AiTrainerPlugin()
    let channel = FlutterMethodChannel(name: instance.channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    let eventChannel = FlutterEventChannel(name: instance.eventName, binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)
    registrar.register(AiTrainerPreviewFactory(viewProvider: instance), withId: instance.viewType)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "camera.requestPermission":
      requestCameraPermission(result: result)
    case "camera.initialize":
      initializeCamera()
      result(["ok": captureSession != nil])
    case "camera.start":
      startCamera()
      result(["ok": true])
    case "camera.stop":
      stopCamera()
      result(["ok": true])
    case "camera.getStatus":
      result([
        "running": running,
        "permission": AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
        "fps": 30.0,
      ])
    case "pose.getStatus":
      result([
        "running": running && landmarker != nil,
        "modelId": "pose_landmarker_lite",
        "backend": "MediaPipe Tasks Vision CPU",
        "modelSha256": "59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a",
      ])
    case "storage.encrypt":
      guard let text = call.arguments as? String else {
        result(FlutterError(code: "STORAGE_ERROR", message: "expected string", details: nil))
        return
      }
      do {
        result(try SecureCrypto().encrypt(text))
      } catch {
        result(FlutterError(code: "STORAGE_ERROR", message: error.localizedDescription, details: nil))
      }
    case "storage.decrypt":
      guard let payload = call.arguments as? [String: Any] else {
        result(FlutterError(code: "STORAGE_ERROR", message: "expected map", details: nil))
        return
      }
      do {
        result(try SecureCrypto().decrypt(payload))
      } catch {
        result(FlutterError(code: "STORAGE_ERROR", message: error.localizedDescription, details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: - Camera

  private func requestCameraPermission(result: @escaping FlutterResult) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      result(["granted": true])
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async { result(["granted": granted]) }
      }
    default:
      result(["granted": false])
    }
  }

  private func initializeCamera() {
    guard captureSession == nil else { return }
    let session = AVCaptureSession()
    session.sessionPreset = .hd1280x720
    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
          let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
    session.addInput(input)
    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    output.setSampleBufferDelegate(self, queue: sessionQueue)
    if session.canAddOutput(output) { session.addOutput(output) }
    captureSession = session
    previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer?.videoGravity = .resizeAspectFill
    initializePose()
  }

  private func initializePose() {
    guard landmarker == nil,
          let url = Bundle.main.url(forResource: "pose_landmarker_lite", withExtension: "task", subdirectory: "flutter_assets/assets/models/pose") else { return }
    do {
      var options = PoseLandmarkerOptions()
      options.baseOptions.modelAssetPath = url.path
      options.runningMode = .liveStream
      options.numPoses = 1
      options.minPoseDetectionConfidence = 0.5
      options.minPosePresenceConfidence = 0.5
      options.minTrackingConfidence = 0.5
      options.resultDelegate = self
      landmarker = try PoseLandmarker(options: options)
    } catch {
      eventSink?(FlutterError(code: "INFERENCE_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  private func startCamera() {
    initializeCamera()
    sessionQueue.async { [weak self] in
      guard let session = self?.captureSession else { return }
      if !session.isRunning { session.startRunning() }
      self?.running = true
    }
  }

  private func stopCamera() {
    running = false
    sessionQueue.async { [weak self] in
      guard let session = self?.captureSession else { return }
      if session.isRunning { session.stopRunning() }
    }
  }

  // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard running, let landmarker = landmarker, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    timestamp &+= 1
    let start = Date()
    do {
      let image = MPImage(sampleBuffer: buffer)
      try landmarker.detectAsync(image: image, timestampInMilliseconds: Int(timestamp))
      lastInferenceMs = Date().timeIntervalSince(start) * 1000
    } catch {
      DispatchQueue.main.async { [weak self] in
        self?.eventSink?(FlutterError(code: "INFERENCE_ERROR", message: error.localizedDescription, details: nil))
      }
    }
  }
}

// MARK: - PoseLandmarkerResultDelegate

extension AiTrainerPlugin: PoseLandmarkerResultDelegate {
  func poseLandmarker(_ poseLandmarker: PoseLandmarker, didOutputResult result: PoseLandmarkerResult, timestampInMilliseconds: Int) {
    let landmarks = result.landmarks.first?.map { lm -> [String: Any] in
      [
        "x": lm.x, "y": lm.y, "z": lm.z,
        "visibility": lm.visibility ?? 0,
        "presence": lm.presence ?? 0,
      ]
    } ?? []
    let world = result.worldLandmarks.first?.map { lm -> [String: Any] in
      ["x": lm.x, "y": lm.y, "z": lm.z]
    } ?? []
    let payload: [String: Any] = [
      "event": "pose_frame",
      "schema_version": 1,
      "timestamp_ms": Int(Date().timeIntervalSince1970 * 1000),
      "landmarks": landmarks,
      "worldLandmarks": world,
      "inference_ms": lastInferenceMs,
    ]
    DispatchQueue.main.async { [weak self] in self?.eventSink?(payload) }
  }
}

// MARK: - Platform view

private final class AiTrainerPreviewFactory: NSObject, FlutterPlatformViewFactory {
  private weak var viewProvider: AiTrainerPlugin?

  init(viewProvider: AiTrainerPlugin) {
    self.viewProvider = viewProvider
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return AiTrainerPreviewView(frame: frame, provider: viewProvider)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class AiTrainerPreviewView: NSObject, FlutterPlatformView {
  private let container = UIView()

  init(frame: CGRect, provider: AiTrainerPlugin?) {
    super.init()
    container.frame = frame
    // The preview layer is attached on the macOS build path once the plugin's
    // previewLayer is available; this file is source-prepared only on Linux.
  }

  func view() -> UIView { container }
}
