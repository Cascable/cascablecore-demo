import Foundation
import UIKit
import CascableCore
import CascableCoreSwift
import Combine

@objc(VideoRecordingViewController) class VideoRecordingViewController: UIViewController, CameraViewController {

    deinit {
        // Turn off live view if it's running.
        stopLiveView()
        // Remove our video state observers.
        videoStateSubscribers.removeAll()
    }

    // MARK: - Setup

    var camera: (NSObject & Camera)?
    var videoStateSubscribers: Set<AnyCancellable> = []

    func setupUI(for camera: (NSObject & Camera)?) {
        self.camera = camera
        guard let camera = camera else { return }

        startLiveView(on: camera)

        camera.videoRecordingStatePublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recordingState in
                self?.updateUIForVideoRecordingState(recordingState)
            }
            .store(in: &videoStateSubscribers)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        recordingStateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15.0, weight: .regular)
    }

    // MARK: - Recording Video

    @IBAction func startOrStopVideoRecording(_ sender: Any?) {
        let responseHandler: ErrorableOperationCallback = { error in
            if let error {
                print("\(CurrentFileName()): Video recording operation failed with error: \(error.localizedDescription)")
            }
        }

        guard let camera else { return }

        if !camera.isRecordingVideo {
            // If you need fine-grained control when invoking focus, see the engageAutoFocus: et. al. methods.
            // IMPORTANT: The error parameter given in the callback only indicates whether the request was sent without error.
            camera.startVideoRecording(responseHandler)
        } else {
            camera.endVideoRecording(responseHandler)
        }
    }

    @IBOutlet var startStopRecordingButton: UIButton!
    @IBOutlet var recordingStateLabel: UILabel!

    func updateUIForVideoRecordingState(_ state: VideoRecordingState) {
        switch state {
        case .notRecording:
            UIView.performWithoutAnimation {
                recordingStateLabel.text = "Not Recording"
                startStopRecordingButton.setTitle("Start Recording", for: .normal)
                startStopRecordingButton.layoutIfNeeded()
            }
        case .recording(let timer):
            UIView.performWithoutAnimation {
                startStopRecordingButton.setTitle("Stop Recording", for: .normal)
                startStopRecordingButton.layoutIfNeeded()
                if let timer {
                    recordingStateLabel.text = "Recording: \(timer.asMinutesAndSeconds)"
                } else {
                    recordingStateLabel.text = "Recording"
                }
            }
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
