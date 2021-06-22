import Foundation
import CascableCore

typealias CameraFileScanningPredicate = (_ item: FileSystemItem) -> Bool
typealias CameraFileScanningCompletion = (_ result: Result<[FileSystemItem], Error>) -> Void

/// The CameraFileScanning class provides helpers for navigating a camera's filesystem hierarchy and extracting files
/// you're interested in.
class CameraFileScanning {

    // MARK: - API

    /// Returns the shared camera scanning object.
    static let shared = CameraFileScanning()

    /// Iterate the camera's filesystem for items. This operation may take a long time.
    ///
    /// - Parameters:
    ///   - camera: The camera to iterate.
    ///   - predicate: The predicate to filter out files. In the filter closure, return `true` if you want the passed item,
    ///                otherwise `false`. Pass `nil` to this parameter to return all files.
    ///   - completionHandler: The completion closure to be triggered once iteration has completed or fails.
    /// - Returns: Returns a `Progress` object tracking the progress of the load, if that information is available from the camera.
    func scanForFiles(in camera: Camera,
                      matching predicate: CameraFileScanningPredicate?,
                      completionHandler: @escaping CameraFileScanningCompletion) -> Progress? {

        guard camera.currentCommandCategoriesContains(.filesystemAccess) else {
            // Can't scan without filesystem access!
            completionHandler(.failure(NSError(cblErrorCode: .incorrectCommandCategory)))
            return nil
        }

        let storageDevices = camera.storageDevices ?? []
        let rootFolders = storageDevices.compactMap({ $0.rootDirectory })

        guard !rootFolders.isEmpty else {
            completionHandler(.failure(NSError(cblErrorCode: .notAvailable)))
            return nil
        }

        findItemsRecursively(in: rootFolders, matching: predicate, completionHandler: completionHandler)

        // Not having progress isn't an error.
        let progresses = storageDevices.compactMap({ $0.catalogProgress })
        guard !progresses.isEmpty else { return nil }

        let totalProgress = Progress(totalUnitCount: Int64(progresses.count))
        progresses.forEach({ totalProgress.addChild($0, withPendingUnitCount: 1) })
        return totalProgress
    }

    // MARK: - Internal

    private init() {}

    // MARK: - Logic

    private func findItemsRecursively(in folders: [FileSystemFolderItem],
                      matching predicate: CameraFileScanningPredicate?,
                      completionHandler: @escaping CameraFileScanningCompletion) {

        findItemsRecursively(in: folders, matching: predicate, previouslyFoundItems: [], completionHandler: completionHandler)
    }

    private func findItemsRecursively(in folders: [FileSystemFolderItem],
                      matching predicate: CameraFileScanningPredicate?,
                      previouslyFoundItems: [FileSystemItem],
                      completionHandler: @escaping CameraFileScanningCompletion) {

        guard !folders.isEmpty else {
            // We've run out of folders to load!
            completionHandler(.success(previouslyFoundItems))
            return
        }

        var foldersRemaining = folders
        let thisFolder = foldersRemaining.removeFirst()

        findItemsRecursively(in: thisFolder, matching: predicate) { result in
            switch result {
            case .failure(let error): completionHandler(.failure(error))
            case .success(let items):
                var updatedItems = previouslyFoundItems
                updatedItems.append(contentsOf: items)
                self.findItemsRecursively(in: foldersRemaining, matching: predicate,
                                          previouslyFoundItems: updatedItems, completionHandler: completionHandler)
            }
        }
    }

    private func findItemsRecursively(in folder: FileSystemFolderItem,
                      matching predicate: CameraFileScanningPredicate?,
                      completionHandler: @escaping CameraFileScanningCompletion) {

        folder.loadChildren { error in
            if let error = error {
                completionHandler(.failure(error))
                return
            }

            let effectivePredicate = predicate ?? { _ in return true }

            var matchedItems: [FileSystemItem] = []
            var childFolders: [FileSystemFolderItem] = []

            let children = folder.children ?? []

            children.forEach({ child in
                if let folder = child as? FileSystemFolderItem {
                    childFolders.append(folder)
                } else if effectivePredicate(child) {
                    matchedItems.append(child)
                }
            })

            self.findItemsRecursively(in: childFolders, matching: effectivePredicate) { result in
                switch result {
                case .failure(let error): completionHandler(.failure(error))
                case .success(let items):
                    var allItems = matchedItems
                    allItems.append(contentsOf: items)
                    completionHandler(.success(allItems))
                }
            }
        }
    }
}

