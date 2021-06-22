import Foundation

public class CascableCoreLicense {

    private init() {}

    @available(*, unavailable, message: "You must supply your own CascableCore license.")
    public static var license: Data {
        return Data(licenseBytes)
    }

    private static let licenseBytes: [UInt8] = []
}
