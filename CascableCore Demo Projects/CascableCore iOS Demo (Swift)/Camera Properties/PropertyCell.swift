import UIKit
import CascableCore
import CascableCoreSwift
import Combine

// This is an ObjC-visible base class so we can use our genericised Swift class with Storyboards.
@objc(PropertyCell) class PropertyCell: UITableViewCell {
    override func awakeFromNib() {
        super.awakeFromNib()
        detailTextLabel?.textColor = .gray
    }
}

// This class uses Combine and the property publishers provided by CascableCoreSwift. If you don't want to use
// Combine, see the `PropertyCell` class in the Objective-C project — the APIs used there can be directly
// translated to Swift.
class TypedPropertyCell<CommonValueType: TypedCommonValue>: PropertyCell {

    convenience init(publisher: AnyPublisher<TypedCameraProperty<CommonValueType>, Never>) {
        self.init(style: .value1, reuseIdentifier: "")
        propertyPublisher = publisher
        subscribeToPublisher(publisher)
    }

    private var subscribers: Set<AnyCancellable> = []

    var propertyPublisher: AnyPublisher<TypedCameraProperty<CommonValueType>, Never>? {
        willSet { subscribers.removeAll() }
        didSet { subscribeToPublisher(propertyPublisher) }
    }

    // MARK: - Reacting To Changes

    func subscribeToPublisher(_ publisher: AnyPublisher<TypedCameraProperty<CommonValueType>, Never>?) {
        guard let propertyPublisher = publisher else { return }

        propertyPublisher
            .receive(on: DispatchQueue.main)
            .compactMap { (property) -> (String, String) in
                // In this map, we try to find the best display values for the user. We use the property's localised
                // display value, the common value, and a fallback string value.

                // - The localised display value is the preferred thing to show to the user. However, it might not be available.

                // - The common value is a "normalised" value that can be used across cameras. It's useful for targeting
                //   settings programatically — for example, you might want to set a camera's white balance to "sunny".

                // - The fallback value may be a camera-specific implementation detail. In general, this isn't super useful
                //   and we're only using it as a last-resort fallback here.

                // Note: It's possible that CascableCore doesn't have a localized name for the language your
                // app is running in. It's a sensible idea to have your own localisations if appropriate.
                let displayName = property.localizedDisplayName ?? "Unknown Property"

                if let localizedValue = property.currentLocalizedDisplayValue {
                    // If CascableCore is giving us a user-appropriate string, that's great!
                    return (displayName, localizedValue)

                } else if let exposureValue = property.currentCommonValue as? UniversalExposurePropertyValue {
                    // Exposure values provide some additional things for us to work with.
                    return (displayName, exposureValue.succinctDescription)

                } else if let fallbackString = property.currentValue?.stringValue {
                    // For this demo, we'll fall back to shoving the value's internal value into a string.
                    // This isn't a good idea for production apps.
                    return (displayName, fallbackString)

                } else {
                    // At this point, the current value of the property has to be nil.
                    return (displayName, "No Value")
                }
            }
            .sink(receiveValue: { [weak self] (propertyName, propertyValue) in
                self?.textLabel?.text = propertyName
                self?.detailTextLabel?.text = propertyValue
            })
            .store(in: &subscribers)
    }
}
