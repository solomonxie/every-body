import Foundation

enum StoreRegion: String {
    case us, cn
}

/// App Store region this install was built for (`make device STORE=cn`); `us` covers Canada/US.
func storeRegion(_ bundle: Bundle = .main) -> StoreRegion {
    StoreRegion(rawValue: bundle.object(forInfoDictionaryKey: "AppStoreRegion") as? String ?? "") ?? .us
}
