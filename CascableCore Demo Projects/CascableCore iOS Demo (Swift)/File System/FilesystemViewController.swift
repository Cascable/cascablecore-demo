import UIKit
import CascableCore

@objc(FilesystemViewController) class FilesystemViewController: UITableViewController, CameraViewController {

    // MARK: - UI and Outlets

    @IBOutlet var busyView: UIView!
    @IBOutlet var progressView: UIProgressView!

    // MARK: - Setup

    var camera: (NSObject & Camera)?

    func setupUI(for camera: (NSObject & Camera)?) {
        self.camera = camera
        guard let camera = camera else { return }
        loadViewIfNeeded()
        showBusyOverlay()

        // CameraFileScanning is a helper class provided with this demo app that iterates through
        // the camera's directory structure and extracts files that the called might be interested in.
        // You're welcome to use this in your own apps, but it may not provide the best UI
        // experience — since it takes an all-or-nothing approach, if the camera has a lot of files
        // your users will see nothing for a long time.
        let scanner = CameraFileScanning.shared

        let predicate: CameraFileScanningPredicate = {
            // We're only interested in images and items that don't have loaded metadata (they're probably images too).
            return $0.isKnownImageType || !$0.metadataLoaded
        }

        let progress = scanner.scanForFiles(in: camera, matching: predicate) { [weak self] result in
            guard let self = self else { return }
            self.hideBusyOverlay()
            switch result {
            case .failure(let error):
                print("\(CurrentFileName()): Got failure when loading! \(error.localizedDescription)")

            case .success(let items):
                print("\(CurrentFileName()): Camera scan got \(items.count) items")
                self.items = items
                self.tableView.reloadData()
            }
        }

        progressView.isHidden = (progress == nil)
        progressView.observedProgress = progress
    }

    // MARK: - Lifecycle

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

    var items: [FileSystemItem] = []

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "itemCell", for: indexPath) as! FilesystemItemCell
        cell.item = items[indexPath.row]
        return cell
    }
}
