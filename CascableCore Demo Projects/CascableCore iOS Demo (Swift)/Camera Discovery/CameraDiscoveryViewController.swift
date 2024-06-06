import UIKit
import CascableCore
import CascableCoreSwift
import CascableCoreSimulatedCamera

@objc(CameraDiscoveryViewController)
class CameraDiscoveryViewController: UIViewController, CameraDiscoveryDelegate {

    // MARK: - Outlets & Lifecycle

    private var lastConnectedCamera: Camera?
    @IBOutlet var titleLabel: UILabel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetDiscovery()
    }

    // MARK: - Camera Discovery Delegate Methods

    func discovery(_ discovery: CameraDiscovery, didDiscover camera: Camera) {
        // We're using the camera's service here to log a bit of info about the camera.
        // A camera's deviceInfo property is often not populated until the camera is connected.

        // All of these properties can be nil at this point, especially when working with "generic" USB cameras.
        let manufacturer = camera.service.manufacturer ?? "unknown"
        let model = camera.service.model ?? "unknown"
        let ipAddress = camera.service.ipv4Address ?? "unknown"
        print("\(CurrentFileName()): Found a \(manufacturer) \(model) at \(ipAddress)!")

        // We only want one camera, so stop searching as soon as we've found one.
        print("\(CurrentFileName()): Stopping camera discovery.")
        discovery.stopSearching()

        connect(to: camera)
    }

    func discovery(_ discovery: CameraDiscovery, didLoseSightOf camera: Camera) {
        // In this demo, we don't care if a camera disappears since we're not maintaining a list of available cameras.
        // Cameras can disappear from discovery after being connected to, which is normal behaviour.
    }

    // MARK: - Connection

    func connect(to camera: Camera) {

        titleLabel.text = "Connecting…"
        print("\(CurrentFileName()): Connecting to \(camera.service.model ?? "unknown")…")

        camera.connect(authenticationRequestCallback: { context in
            // This callback will be called if connection is halted due to the camera requiring authentication of some kind.

            // This and the `authenticationResolvedCallback` callback will always be called in pairs. Authentication UI
            // should be shown to the user in this callback, then hidden (if still visible) in `authenticationResolvedCallback`.
            // Which action should be taken by the user is defined in the `context` object. See `displayAuthenticationUI(for:)`
            // below for examples.
            self.displayAuthenticationUI(for: context)

        }, authenticationResolvedCallback: {
            // This callback will be called after authentication has been "resolved" - hide any displayed authentication UI.
            self.dismissAuthenticationUI()

        }, completionCallback: { [weak self] error, warnings in
            // This is the completion callback, which will be called after the connection has successfully
            // completed or has failed.
            guard let self else { return }

            if let error = error {
                if error.asCascableCoreError != .cancelledByUser {
                    // If the user cancelled, don't display an error.
                    self.displayConnectionError(error)
                }

                self.resetDiscovery()
            } else {
                self.transitionToMainDemoScreen(with: camera)
            }
        })
    }

    private var authenticationAlert: UIAlertController? = nil

    func displayAuthenticationUI(for context: CameraAuthenticationContext) {

        // What we display to the user depends on which kind of authentication the camera wants. Currently,
        // there are three kinds:
        //
        // - "Interact with camera" means that the only thing you can do is cancel the connection. The user must
        //   physically interact with the camera to approve the connection.
        //
        // - "Username and password" means that a username and password should be collected and submitted.
        //
        // - "Four digit code" means that a four digic numeric code should be collected and submitted.

        switch context.type {
        case .interactWithCamera: presentInteractWithCameraAuthenticationUI(for: context)
        case .usernameAndPassword: presentUsernameAndPasswordAuthenticationUI(for: context)
        case .fourDigitNumericCode: presentFourDigitNumericCodeAuthenticationUI(for: context)
        @unknown default: fatalError("Got unknown camera authentication type!")
        }
    }

    func presentInteractWithCameraAuthenticationUI(for context: CameraAuthenticationContext) {
        // Here, we display an authentication alert instructing the user to interact with the camera to continue.
        // When the user does so, the `authenticationResolvedCallback` given to the camera's connection invocation
        // will be called.

        let alert = UIAlertController(title: "Pairing Required!",
                                      message: "Please follow the instructions on your camera's screen to continue.",
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Disconnect", style: .cancel, handler: { [weak self] _ in
            self?.dismissAuthenticationUI()
            context.submitCancellation()
        }))

        authenticationAlert = alert
        present(alert, animated: true)
    }

    func presentUsernameAndPasswordAuthenticationUI(for context: CameraAuthenticationContext) {
        // Here, we display an authentication alert asking for a username and password, which we then submit to the camera
        // via the given authentication context. When the user does so, the `authenticationResolvedCallback` given to the
        // camera's connection invocation will be called.

        // Some cameras let us try again if incorrect details were submitted.
        let previousAttemptFailed = context.previousSubmissionRejected

        let alert = UIAlertController(title: previousAttemptFailed ? "Incorrect Username/Password" : "Authentication Required",
                                      message: "Please enter your camera's username and password.",
                                      preferredStyle: .alert)

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "Username"
        })

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        })

        alert.addAction(UIAlertAction(title: "Disconnect", style: .cancel, handler: { [weak self] action in
            // We dismiss the alert right away here, but we don't have to — we could instead disable the buttons etc
            // and wait for the `authenticationResolvedCallback` to be called above.
            self?.dismissAuthenticationUI()
            context.submitCancellation()
        }))

        alert.addAction(UIAlertAction(title: "Submit", style: .default, handler: { [weak self] action in
            // We dismiss the alert right away here, but we don't have to — we could instead disable the buttons etc
            // and wait for the `authenticationResolvedCallback` to be called above.
            let userName = alert.textFields?.first?.text ?? ""
            let password = alert.textFields?.last?.text ?? ""
            self?.dismissAuthenticationUI()
            context.submitUserName(userName, password: password)
        }))

        authenticationAlert = alert
        present(alert, animated: true)
    }

    func presentFourDigitNumericCodeAuthenticationUI(for context: CameraAuthenticationContext) {
        // Here, we display an authentication alert asking for a four-digit code, which we then submit to the camera
        // via the given authentication context. When the user does so, the `authenticationResolvedCallback` given to the
        // camera's connection invocation will be called.

        // Some cameras let us try again if incorrect details were submitted.
        let previousAttemptFailed = context.previousSubmissionRejected

        let alert = UIAlertController(title: previousAttemptFailed ? "Incorrect Passcode" : "Authentication Required",
                                      message: "Please enter your camera's passcode.",
                                      preferredStyle: .alert)

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "Passcode"
            textField.isSecureTextEntry = true
            textField.keyboardType = .numberPad
        })

        alert.addAction(UIAlertAction(title: "Disconnect", style: .cancel, handler: { [weak self] action in
            // We dismiss the alert right away here, but we don't have to — we could instead disable the buttons etc
            // and wait for the `authenticationResolvedCallback` to be called above.
            self?.dismissAuthenticationUI()
            context.submitCancellation()
        }))

        alert.addAction(UIAlertAction(title: "Submit", style: .default, handler: { [weak self] action in
            // We dismiss the alert right away here, but we don't have to — we could instead disable the buttons etc
            // and wait for the `authenticationResolvedCallback` to be called above.
            let code = alert.textFields?.first?.text ?? ""
            self?.dismissAuthenticationUI()
            context.submitNumericCode(code)
        }))

        authenticationAlert = alert
        present(alert, animated: true)
    }

    func dismissAuthenticationUI() {
        // This can be called either from our own UI methods or from the `authenticationResolvedCallback` during connection.
        guard let authenticationAlert else { return }
        authenticationAlert.dismiss(animated: true)
        self.authenticationAlert = nil
    }

    // MARK: - Connection UI

    func resetDiscovery() {
        titleLabel.text = "Searching for cameras…"
        print("\(CurrentFileName()): Starting camera discovery")

        // Set up discovery using delegate methods. You can also use KVO or block callbacks.
        let discovery = CameraDiscovery.shared

        // Configure the simulated camera.
        var config = SimulatedCameraConfiguration.default
        config.connectionAuthentication = .none
        config.apply()

        // Set this to `true` to use the simulated camera. By default we want to use a real camera.
        discovery.setEnabled(false, forPluginWithIdentifier: SimulatedCameraPluginIdentifier)

        // The client name will be shown on the screen of some cameras when pairing.
        // It must be set before you start searching for cameras.
        discovery.clientName = "CascableCore Demo"
        discovery.delegate = self
        discovery.beginSearching()
    }

    func displayConnectionError(_ error: Error) {
        let alert = UIAlertController(title: "Connection Error!", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
            alert.dismiss(animated: true, completion: nil)
        }))

        present(alert, animated: true, completion: nil)
    }

    func transitionToMainDemoScreen(with camera: Camera) {
        print("\(CurrentFileName()): Connection to \(camera.service.model ?? "unknown") successful - transitioning to main screen")
        lastConnectedCamera = camera
        performSegue(withIdentifier: "mainDemoScreen", sender: nil)
    }

    // MARK: - Navigation

    @IBAction func unwindToDiscovery(_ unwindSegue: UIStoryboardSegue) {
        // This is a no-op method to support storyboard segue unwinding to this view controller.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Hand off our connected camera to the next view controller.
        if let destination = segue.destination as? CameraViewController, let camera = lastConnectedCamera as? (Camera & NSObject) {
            destination.setupUI(for: camera)
        }
    }

}
