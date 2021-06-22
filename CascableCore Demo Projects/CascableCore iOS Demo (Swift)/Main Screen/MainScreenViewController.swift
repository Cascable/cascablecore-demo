import Foundation
import UIKit
import CascableCore
import CascableCoreSwift

@objc(MainScreenViewController) class MainScreenViewController: UITableViewController, CameraViewController {

    // MARK: - Lifecycle

    func setupUI(for camera: (Camera & NSObject)?) {
        self.camera = camera

        if let camera = camera {
            var titleComponents: [String] = []
            if let manufacturer = camera.deviceInfo?.manufacturer { titleComponents.append(manufacturer) }
            if let model = camera.deviceInfo?.model { titleComponents.append(model) }

            if !titleComponents.isEmpty {
                title = titleComponents.joined(separator: " ")
            } else if let displayName = camera.friendlyDisplayName {
                title = displayName
            } else {
                title = "Unknown Camera"
            }
        } else {
            title = ""
        }
    }

    var camera: (Camera & NSObject)? {
        willSet { connectionStateObserver?.invalidate() }
        didSet {
            if let camera = camera { setupDisconnectionObserver(on: camera) }
        }
    }

    @IBOutlet var busyView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Since our busy overlay is a floating view in the storyboard, it needs a little setup.
        busyView.translatesAutoresizingMaskIntoConstraints = false
        busyView.layer.cornerRadius = 20.0
        busyView.layer.masksToBounds = true

        NSLayoutConstraint.activate([
            busyView.widthAnchor.constraint(equalToConstant: 200.0),
            busyView.heightAnchor.constraint(equalToConstant: 200.0)
        ])
    }

    deinit {
        connectionStateObserver?.invalidate()
        connectionStateObserver = nil
    }

    // MARK: - Disconnecting

    private var connectionStateObserver: NSKeyValueObservation? = nil

    func setupDisconnectionObserver<T>(on camera: T) where T: NSObject & Camera {
        // We add an observer to the camera's connection state so we can react to disconnections. This lets us have a
        // single code path for both disconnections we invoke and unexpected disconnections due to network dropouts etc.
        connectionStateObserver = camera.observe(\.connectionState) { [weak self] camera, change in
            guard let self = self else { return }

            // Only react if we still have the camera and its connection state switched to .notConnected.
            guard let camera = self.camera, camera.connectionState == .notConnected else { return }
            self.handleDisconnect(from: camera)
        }
    }

    @IBAction func disconnectFromCamera(_ sender: Any?) {
        // Disconnect from the camera. We don't _really_ care about the response to this since our connectionState
        // observer deals with disconnections. This is called by the "Disconnect" button in the UI.
        camera?.disconnect({ error in
            if let error = error { print("\(CurrentFileName()): Disconnection got error: \(error.localizedDescription)") }
        }, callbackQueue: .main)
    }

    private func handleDisconnect(from camera: Camera) {
        // The disconnectionWasExpected property is only valid during a KVO notification triggered by the camera's
        // connectionState or connected properties changing. It's useful for deciding to display an error to the user.

        self.camera = nil

        if camera.disconnectionWasExpected {
            print("\(CurrentFileName()): Expected disconnection encountered - unwinding to camera discovery.")
            performSegue(withIdentifier: "unwindToDiscovery", sender: nil)

        } else {
            // In this case, the disconnection was not expected — it may have been caused by a network dropout, etc.
            // Display a warning to the user.
            print("\(CurrentFileName()): Unexpected disconnection encountered! Alerting before unwinding to camera discovery.")

            let alert = UIAlertController(title: "Camera Disconnected!",
                                          message: "The camera disconnected unexpectedly. This may have been caused by " +
                                                   "moving too far away from the camera, or by turning it off.",
                                          preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { [weak self] _ in
                alert.dismiss(animated: true, completion: nil)
                self?.performSegue(withIdentifier: "unwindToDiscovery", sender: nil)
            }))

            present(alert, animated: true, completion: nil)
        }
    }

    // MARK: - Camera Mode Switching

    func ensureCameraAllows(_ category: AvailableCommandCategory, thenPerform segue: String) {

        // Cameras often don't allow all functionality at once. A common division of functionality is remote shooting
        // and access to the camera's filesystem — you can do either, but not both.

        // However, some cameras *do* allow both, so the `currentCommandCategories` property is actually an optionset.
        // To aid working with this, there's APIs to query whether the camera currently allows a given command category:

        // camera.currentCommandCategoriesContains(.remoteShooting)

        // However, it's a harmless operation to set the command category to one that's already allowed. Therefore, to
        // reduce code paths, in this example we just set the required command category without checking if it's
        // already available first.

        let categoryName = (category == .remoteShooting ? "remote shooting" : "filesystem access")
        print("\(CurrentFileName()): Switching camera to \(categoryName)…")

        view.isUserInteractionEnabled = false
        showBusyOverlay()

        camera?.setCurrentCommandCategories(category, completionCallback: { [weak self] error in
            guard let self = self else { return }
            self.view.isUserInteractionEnabled = true
            self.hideBusyOverlay()
            if let error = error {
                print("\(CurrentFileName()): …category switch got error: \(error.localizedDescription).")
                self.displayModeSwitchError(error)
            } else {
                print("\(CurrentFileName()): …category switch complete.")
                self.performSegue(withIdentifier: segue, sender: nil)
            }
        })
    }

    func displayModeSwitchError(_ error: Error) {
        let alert = UIAlertController(title: "Error!", message: "The camera doesn't support this functionality.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
            alert.dismiss(animated: true, completion: nil)
        }))

        present(alert, animated: true, completion: nil)
    }

    func showBusyOverlay() {
        busyView.removeFromSuperview()
        view.addSubview(busyView)

        NSLayoutConstraint.activate([
            busyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            busyView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func hideBusyOverlay() {
        busyView.removeFromSuperview()
    }

    // MARK: - Table View Data Source

    enum DemoScreenRow: Int {
        case liveView = 0
        case properties = 1
        case fileSystem = 2
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let tappedRow = DemoScreenRow(rawValue: indexPath.row) else { return }

        switch tappedRow {
        case .liveView: ensureCameraAllows(.remoteShooting, thenPerform: "liveViewShooting")
        case .properties: ensureCameraAllows(.remoteShooting, thenPerform: "properties")
        case .fileSystem: ensureCameraAllows(.filesystemAccess, thenPerform: "filesystem")
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Hand off our connected camera to the next view controller.
        if let destination = segue.destination as? CameraViewController, let camera = camera {
            destination.setupUI(for: camera)
        }
    }
}
