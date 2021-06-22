import UIKit
import CascableCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Apply the CascableCore license. IMPORTANT: You must supply your own CascableCore license.
        // See http://developer.cascable.se/ for details.
        switch CascableCoreLicenseVerification.apply(license: CascableCoreLicense.license) {
        case .success: print("License was applied successfully.")
        case .expired: print("Applying license failed: Expired!")
        case .invalidLicense: print("Applying license failed: Invalid!")
        @unknown default: print("Applying license failed: Unknown reason!")
        }

        return true
    }

}

