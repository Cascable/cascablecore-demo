import Foundation
import UIKit
import CascableCore
import CascableCoreSwift
import Combine

@objc(LiveViewAndShootingViewController) class LiveViewAndShootingViewController: UIViewController, CameraViewController {

    deinit {
        // Make sure we remove our shot preview observer so it doesn't get fired after we're deallocated!
        if let observer = shotPreviewObserver { camera?.removeShotPreviewObserver(with: observer) }

        // Turn off live view if it's running.
        stopLiveView()
    }

    // MARK: - Setup

    var camera: (NSObject & Camera)?

    func setupUI(for camera: (NSObject & Camera)?) {
        self.camera = camera
        guard let camera = camera else { return }

        // Shot previews let us preview shots with a reasonably high quality as they're taken.
        shotPreviewObserver = camera.addShotPreviewObserver({ [weak self] delivery in
            self?.handleShotPreview(delivery)
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

    var shotPreviewObserver: String?
    var lastShotPreviewImage: UIImage?

    func handleShotPreview(_ previewDelivery: ShotPreviewDelivery) {

        // Shot previews get delivered (on supported cameras) when a new preview is available. Previews will become invalid
        // after an amount of time, so it's important to check they're still valid before fetching.

        // Since fetching a preview can delay other commands, they're only fetched if you ask for them, which
        // we do here 100% of the time.

        guard previewDelivery.isValid else {
            print("\(CurrentFileName()): Shot preview received, but it's invalid!")
            return
        }

        print("\(CurrentFileName()): Fetching shot preview…")

        previewDelivery.fetchShotPreview { [weak self] sourceData, previewImage, error in
            guard let self = self else { return }

            // sourceData is the raw image data as received from the camera, before any rotation etc. is applied.
            // This can be useful if you want to apply your own tranformations to the image.

            guard error == nil, let preview = previewImage else {
                print("\(CurrentFileName()): Shot preview fetch failed with error: \(error?.localizedDescription ?? "unknown")")
                return
            }

            print("Shot preview fetch succeeded")
            self.lastShotPreviewImage = preview
            self.performSegue(withIdentifier: "shotPreview", sender: self)
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
