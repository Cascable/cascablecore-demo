import UIKit
import CascableCore

@objc(FilesystemItemCell) class FilesystemItemCell: UITableViewCell {

    var item: FileSystemItem! {
        didSet {
            loadingState = .start
            advanceLoadingState()
        }
    }

    // MARK: - Outlets & UI

    @IBOutlet var fileNameLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var loadingSpinner: UIActivityIndicatorView!

    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - UI State

    var loadingState: LoadingState = .start

    enum LoadingState {
        case start
        case loadingMetadata
        case loadingThumbnail
        case done

        var next: LoadingState {
            switch self {
            case .start: return .loadingMetadata
            case .loadingMetadata: return .loadingThumbnail
            case .loadingThumbnail: return .done
            case .done: return .start
            }
        }
    }

    func advanceLoadingState() {

        // File system items are very lazy — they never start with any image properties (thumbnail, preview)
        // loaded, and they sometimes don't even have basic metadata like filename etc.

        // To deal with this, we'll build a little state machine that goes [start -> load metadata -> load thumbnail -> done].

        loadingState = loadingState.next
        updateUI(for: loadingState)

        switch loadingState {
        case .loadingMetadata: loadMetadataThenAdvanceState()
        case .loadingThumbnail: loadThumbnailThenAdvanceState()
        default: break
        }
    }

    func updateUI(for state: LoadingState) {
        switch state {
        case .start, .loadingMetadata:
            // At this point, we have nothing.
            thumbnailImageView.image = nil
            fileNameLabel.text = "Loading…"
            dateLabel.text = ""
            loadingSpinner.startAnimating()

        case .loadingThumbnail:
            // At this point, we should have some text metadata.
            fileNameLabel.text = item.name
            if let date = item.dateCreated {
                dateLabel.text = dateFormatter.string(from: date)
            } else {
                dateLabel.text = "Unknown Date"
            }

        case .done:
            // We should have everything now.
            loadingSpinner.stopAnimating()
        }
    }

    func loadMetadataThenAdvanceState() {

        guard !item.metadataLoaded else {
            // If the metadata is already loaded, we're good.
            advanceLoadingState()
            return
        }

        // It's possible that the cell will be recycled while we're loading (say, if the user scrolls away), so
        // we should keep track of this so we don't clash metadata.
        let itemAtStartOfStep = item

        item.loadMetadata { [weak self] error in
            guard let self = self else { return }
            if let error = error { print("\(CurrentFileName()): Got error when loading metadata: \(error.localizedDescription)") }
            guard self.item.isEqual(itemAtStartOfStep) else { return }
            self.advanceLoadingState()
        }
    }

    func loadThumbnailThenAdvanceState() {

        item.fetchThumbnail(preflightBlock: { [weak self] item in
            // The preflight block gets called just before the image starts to load. Since cameras
            // tend to queue requests, it may be a little while before it gets around to loading this
            // thumbnail. The preflight block allows us to cancel the request if it's not needed any
            // more — for instance, if the user has already scrolled away.
            return item.isEqual(self?.item)

        }, thumbnailDeliveryBlock: { [weak self] item, error, imageData in
            guard let self = self else { return }
            if let error = error { print("\(CurrentFileName()): Got error when loading thumbnail: \(error.localizedDescription)") }
            guard self.item.isEqual(item) else { return }

            if let data = imageData {
                let image = UIImage(data: data)
                self.thumbnailImageView.image = image
            }

            self.advanceLoadingState()
        })
    }
}
