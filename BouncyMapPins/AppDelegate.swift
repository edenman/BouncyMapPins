import UIKit
import GoogleMaps

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  let mapsApiKey = "ENTER-UR-MAP-KEY-HERE"

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

    GMSServices.provideAPIKey(mapsApiKey)

    let window = UIWindow(frame: UIScreen.main.bounds)
    let rootViewController = MyViewController()
    window.rootViewController = rootViewController
    window.makeKeyAndVisible()
    self.window = window

    return true
  }
}
