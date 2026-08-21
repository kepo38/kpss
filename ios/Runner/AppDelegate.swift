import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private weak var recordingShield: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onScreenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    DispatchQueue.main.async { [weak self] in
      self?.refreshRecordingShield()
    }
  }

  @objc private func onScreenCaptureChanged() {
    refreshRecordingShield()
  }

  /// Ekran kaydı sırasında içeriği kapatır (iOS’ta FLAG_SECURE eşdeğeri yok).
  private func refreshRecordingShield() {
    let recording = UIScreen.main.isCaptured
    let host = window ?? UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)

    guard let window = host else { return }

    if recording {
      if recordingShield == nil {
        let shield = UIView(frame: window.bounds)
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shield.backgroundColor = .black
        shield.isUserInteractionEnabled = true
        let label = UILabel()
        label.text = "Ekran kaydı sırasında içerik gizlenir"
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        shield.addSubview(label)
        NSLayoutConstraint.activate([
          label.centerXAnchor.constraint(equalTo: shield.centerXAnchor),
          label.centerYAnchor.constraint(equalTo: shield.centerYAnchor),
          label.leadingAnchor.constraint(equalTo: shield.leadingAnchor, constant: 24),
          label.trailingAnchor.constraint(equalTo: shield.trailingAnchor, constant: -24),
        ])
        window.addSubview(shield)
        recordingShield = shield
      }
      if let shield = recordingShield {
        window.bringSubviewToFront(shield)
      }
    } else {
      recordingShield?.removeFromSuperview()
      recordingShield = nil
    }
  }
}
