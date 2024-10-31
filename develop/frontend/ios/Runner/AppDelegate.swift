import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    if let apiKey = getGoogleMapsAPIKey() {
      GMSServices.provideAPIKey(apiKey)
    } else {
      print("Errore: API Key non trovata")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Funzione per leggere il file .env
  private func getGoogleMapsAPIKey() -> String? {
    guard let envPath = Bundle.main.path(forResource: "config", ofType: "env") else {
      return nil
    }
    do {
      let envContent = try String(contentsOfFile: envPath)
      let lines = envContent.split(separator: "\n")
      for line in lines {
        let parts = line.split(separator: "=")
        if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == "GOOGLE_MAPS_API_KEY" {
          return parts[1].trimmingCharacters(in: .whitespaces)
        }
      }
    } catch {
      print("Errore nella lettura del file .env: \(error)")
    }
    return nil
  }
}
