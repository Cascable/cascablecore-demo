import Foundation
import UIKit
import CascableCore
import CascableCoreSwift
import Combine

@objc(LiveViewAndShootingViewController) class LiveViewAndShootingViewController: UIViewController, CameraViewController {

    deinit {
        // Make sure we remove our camera-initiated transfer handler so it doesn't get fired after we're deallocated!
        if let observer = cameraInititatedTransferToken { camera?.removeCameraInitiatedTransferHandler(with: observer) }

        // Turn off live view if it's running.
        stopLiveView()
    }

    // MARK: - Setup

    var camera: (NSObject & Camera)?

    func setupUI(for camera: (NSObject & Camera)?) {
        self.camera = camera
        guard let camera = camera else { return }

        // In order to show previews of shots after the shutter has been fired, we need to register a
        // camera-initiated transfer handler.
        cameraInititatedTransferToken = camera.addCameraInitiatedTransferHandler({ [weak self] request in
            self?.handleCameraInitiatedTransferRequest(request)
        })

        startLiveView(on: camera)
    }

    // MARK: - Shooting Images

    @IBAction func shootImage(_ sender: Any?) {
        // If you need fine-grained control when invoking the focus and shutter, see the engageAutoFocus: et. al. methods.
        // IMPORTANT: The error parameter given in the callback only indicates whether the request was sent without error.
        // Whether or not the shutter was actually fired is a complex decision tree made by the camera, depending on
        // various camera settings and whether or not autofocus was successful etc etc. The result of this decision is not returned.

        camera?.invokeOneShotShutterExplicitlyEngagingAutoFocus(true, completionCallback: { error in
            if let error = error {
                print("\(CurrentFileName()): Shot trigger failed with error: \(error.localizedDescription)")
            } else {
                print("\(CurrentFileName()): Shot trigger succeeded")
            }
        })
    }

    // MARK: - Shot Preview

    var cameraInititatedTransferToken: String?
    var lastShotPreviewImage: UIImage?

    func handleCameraInitiatedTransferRequest(_ request: CameraInitiatedTransferRequest) {

         // Camera-initated transfer requests get sent by supported cameras when a new photo has been taken and the
         // camera is presenting on opportunity for that photo to be transferred to a connected host. Transfer requests
         // can become invalid after an amount of time, so it's important to check they're still valid before fetching them.

         // In some situations, this transfer may be the *only* destination of an image — for example, if the camera
         // doesn't have a memory card present or is set to a "host only" image saving mode. If this is the case, the
         // request's `-isOnlyDestinationForImage` property will be set to `YES`. These requests should be executed
         // with the `CBLCameraInitiatedTransferRepresentationOriginal` representation to get the original image file
         // and to avoid data loss. However, for this example we're going to ignore that and only care about previews.

         // Since executing a transfer can delay other commands, they're only executed if you ask for them, which we do
         // here 100% of the time if a preview representation is available.

        guard request.isValid else {
            print("\(CurrentFileName()): Camera-initated transfer request received, but it's invalid")
            return
        }

        guard request.canProvide(.preview) else {
            print("\(CurrentFileName()): Camera-initated transfer request received, but it can't provide a preview representation")
            return
        }

        print("\(CurrentFileName()): Fetching preview…")

         // The `representations` parameter is an option set — we can request both the preview and original representations
         // if we want. However, only requesting a preview allows CascableCore to optimise the request and transfer less
         // data from the camera in certain circumstances – reducing the time taken.

        request.executeTransfer(for: .preview, completionQueue: .main) { result, error in
            guard error == nil, let result = result else {
                print("\(CurrentFileName()): Camera-initiated transfer failed with error: \(String(describing: error))")
                return
            }

            // At this point, the transfer from the camera is complete and we can use the result object to get at
            // the transferred image representations. In this example, we just want to display a preview image
            // on screen — for more advanced operations, we can write the result out to disk or get it as a raw
            // data object.

            result.generatePreviewImage { [weak self] previewImage, previewError in
                // It's rare that we can fail at this point, but it _is_ possible — for example, if the source image
                // is a RAW format we don't know how to handle yet.
                guard previewError == nil, let image = previewImage else {
                    print("\(CurrentFileName()): Failed to generate preview image with error: \(String(describing: previewError))")
                    return
                }

                self?.lastShotPreviewImage = image
                self?.performSegue(withIdentifier: "shotPreview", sender: self)
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let shotPreview = segue.destination as? ShotPreviewViewController {
            shotPreview.loadViewIfNeeded()
            shotPreview.imageView.image = lastShotPreviewImage
        }
    }

    // MARK: - Live View

    @IBOutlet var liveViewImageView: UIImageView!

    // We store our Combine subscribers in here.
    private var liveViewSubscribers: Set<AnyCancellable> = []

    func startLiveView(on camera: Camera) {

        // Make sure we're not subscribing more than once.
        liveViewSubscribers.removeAll()

        // In this example, we're using the Combine publisher provided to us by CascableCoreSwift. To use the "plain"
        // API, which doesn't use Combine, see the LiveViewAndShootingViewController.m file in the Objective-C
        // example — the APIs used there translate directly into Swift.

        // The Combine publisher manages starting and stopping live view, etc. All we need to do is to subscribe to it.

        camera.liveViewPublisher(options: [.maximumFramesPerSecond: FrameRate(fps: 30.0)])
            .receive(on: DispatchQueue.main)
            .sinkWithReadyHandler { [weak self] terminationReason in

                // The termination reason lets us know why live view finished.
                // We might want to display an error to the user if it finished abnormally.
                switch terminationReason {
                case .finished: print("\(CurrentFileName()): Live view terminated normally.")
                case .failure(let error): print("\(CurrentFileName()): Live view failed with error: \(error.localizedDescription)")
                }

                self?.stopLiveView()

            } receiveValue: { [weak self] frame, readyForNextFrame in
                // CascableCoreSwift provides .sinkWithReadyHandler, which works like .sink except it can manage
                // demand for live view frames nicely. It'll wait to issue demand for more live view frames until
                // we're ready for more. Here we call it immediately, but if we wanted to implement a background
                // image processing pipeline, this will help prevent buffer backfill.
                self?.liveViewImageView.image = frame.image

                // We must call the ready handler once we're ready for more live view frames. Since we want a nice,
                // smooth image, we'll call the completion handler without delay.
                readyForNextFrame()
            }
            .store(in: &liveViewSubscribers)
    }

    func stopLiveView() {
        // The camera's live view frame publisher will automatically shut off live view when there's no subscribers
        // left, so all we need to do is remove our observers.
        liveViewSubscribers.removeAll()
    }

}
