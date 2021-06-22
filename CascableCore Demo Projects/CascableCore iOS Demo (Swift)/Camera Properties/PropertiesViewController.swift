import UIKit
import CascableCore
import CascableCoreSwift
import Combine

// This class uses Combine and the property publishers provided by CascableCoreSwift. If you don't want to use
// Combine, see the `PropertyCell` class in the Objective-C project — the APIs used there can be directly
// translated to Swift.
@objc(PropertiesViewController) class PropertiesViewController: UITableViewController, CameraViewController {

    func setupUI(for camera: (NSObject & Camera)?) {
        self.camera = camera
        tableView.reloadData()

        // Many cameras (particularly mirrorless ones) don't populate all of their properties until live view is running,
        // since metering systems etc. are directly linked to the sensor being active. So, even though we're not displaying
        // the image, we should enable live view to get the best data.

        // The exception to this, though, is cameras that support remote control without live view.

        // We don't need to do anything once live view is active - CameraProperty objects (and Combine publishers) will
        // pick up all changes to property values, even if the value was nil before enabling live view. For the UI,
        // our table cells are observing value changes individually.

        camera?.liveViewPublisher(options: [.maximumFramesPerSecond: FrameRate(fps: 4.0)])
            .sinkWithReadyHandler(receiveCompletion: { [weak self] terminationReason in
                self?.liveViewObservers.removeAll()
                switch terminationReason {
                case .finished: print("\(CurrentFileName()): Live view stopped.")
                case .failure(let error): print("\(CurrentFileName()): Live view failed: \(error.localizedDescription)")
                }
            }, receiveValue: { frame, readyHandler in
                // Since we're not actually using the frames here, we don't need to do much. However, we *do* need to
                // call the ready handler. Since we've asked the publisher to target a low framerate, we don't need
                // to manage that here in order to keep CPU etc usage low.
                readyHandler()
            }).store(in: &liveViewObservers)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Since the live view publisher manages live view for us, all we need to do is stop observing.
        liveViewObservers.removeAll()
    }

    var camera: (NSObject & Camera)?
    var liveViewObservers: Set<AnyCancellable> = []

    // MARK: - Model

    struct PropertyRow<T: TypedCommonValue> {
        let index: Int
        let propertyIdentifier: TypedIdentifier<T>
    }

    struct PropertyRows {
        let aperture = PropertyRow<ApertureValue>(index: 0, propertyIdentifier: .aperture)
        let autoExposureMode = PropertyRow<PropertyCommonValueAutoExposureMode>(index: 1, propertyIdentifier: .autoExposureMode)
        let batteryLevel = PropertyRow<PropertyCommonValueBatteryLevel>(index: 2, propertyIdentifier: .batteryPowerLevel)
        let driveMode = PropertyRow<PropertyCommonValueDriveMode>(index: 3, propertyIdentifier: .driveMode)
        let exposureCompensation = PropertyRow<ExposureCompensationValue>(index: 4, propertyIdentifier: .exposureCompensation)
        let iso = PropertyRow<ISOValue>(index: 5, propertyIdentifier: .iso)
        let lightMeterStatus = PropertyRow<PropertyCommonValueLightMeterStatus>(index: 6, propertyIdentifier: .lightMeterStatus)
        let lightMeterReading = PropertyRow<ExposureCompensationValue>(index: 7, propertyIdentifier: .lightMeterReading)
        let shotsAvailable = PropertyRow<Int>(index: 8, propertyIdentifier: .shotsAvailable)
        let shutterSpeed = PropertyRow<ShutterSpeedValue>(index: 9, propertyIdentifier: .shutterSpeed)
        let whiteBalance = PropertyRow<PropertyCommonValueWhiteBalance>(index: 10, propertyIdentifier: .whiteBalance)
    }

    let model = PropertyRows()

    // MARK: - Table View Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 11
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let camera = camera else { return PropertyCell() }

        switch indexPath.row {
        case model.aperture.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.aperture.propertyIdentifier))

        case model.autoExposureMode.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.autoExposureMode.propertyIdentifier))

        case model.batteryLevel.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.batteryLevel.propertyIdentifier))

        case model.driveMode.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.driveMode.propertyIdentifier))

        case model.exposureCompensation.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.exposureCompensation.propertyIdentifier))

        case model.iso.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.iso.propertyIdentifier))

        case model.lightMeterStatus.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.lightMeterStatus.propertyIdentifier))

        case model.lightMeterReading.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.lightMeterReading.propertyIdentifier))

        case model.shotsAvailable.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.shotsAvailable.propertyIdentifier))

        case model.shutterSpeed.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.shutterSpeed.propertyIdentifier))

        case model.whiteBalance.index:
            return TypedPropertyCell(publisher: camera.publisher(for: model.whiteBalance.propertyIdentifier))

        default: return PropertyCell()
        }
    }
}
