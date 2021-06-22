import UIKit
import CascableCore
import CascableCoreSwift

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

        camera.connect(completionCallback: { [weak self] error, warnings in
            guard let self = self else { return }

            if let error = error {
                if error.asCascableCoreError != .cancelledByUser {
                    // If the user cancelled, don't display an error.
                    self.displayConnectionError(error)
                }

                self.resetDiscovery()
            } else {
                self.transitionToMainDemoScreen(with: camera)
            }

        }, userInterventionCallback: { [weak self] shouldDisplayUserInterventionDialog, cancelConnectionHandler in
            guard let self = self else { return }

            // This closure will be called if connection is halted due to the user needing to perform one or more
            // actions on the camera itself. When this happens, you should display UI to the user telling them
            // to look at the camera.

            // This will be called either zero or two times. Zero if no user intervention is required, twice if it is — once when
            // it's appropriate to show UI to tell the user to look at the camera (the shouldDisplayUserInterventionDialog
            // parameter will be `true`), and once when that UI can be dismissed (the shouldDisplayUserInterventionDialog
            // parameter will be false`).

            // The cancelConnectionHandler parameter will be non-nil when shouldDisplayUserInterventionDialog is `true`,
            // and can be called to cancel the connection and abort the pairing.
            if shouldDisplayUserInterventionDialog {
                self.displayPairingRequiredUI(with: cancelConnectionHandler)
            } else {
                self.dismissPairingRequiredUI()
            }
        })
    }

    private var pairingAlert: UIAlertController? = nil

    func displayPairingRequiredUI(with cancelConnection: (() -> Void)?) {

        let alert = UIAlertController(title: "Pairing Required!",
                                      message: "Please follow the instructions on your camera's screen to continue.",
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel Connection", style: .cancel, handler: { [weak self] _ in
            cancelConnection?()
            self?.dismissPairingRequiredUI()
        }))

        pairingAlert = alert
        present(alert, animated: true, completion: nil)
    }

    func dismissPairingRequiredUI() {
        guard let alert = pairingAlert else { return }
        alert.dismiss(animated: true) { [weak self] in
            self?.pairingAlert = nil
        }
    }

    // MARK: - Connection UI

    func resetDiscovery() {
        titleLabel.text = "Searching for cameras…"
        print("\(CurrentFileName()): Starting camera discovery")

        // Set up discovery using delegate methods. You can also use KVO or block callbacks.
        let discovery = CameraDiscovery.shared

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
