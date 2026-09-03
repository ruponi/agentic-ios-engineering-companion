#if canImport(FoundationModels)
import FoundationModels
#endif

enum OnDeviceModelCapability: Equatable {
    case available
    case deviceIneligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case frameworkUnavailable
}

struct OnDeviceModelCapabilityDetector {
    func current() -> OnDeviceModelCapability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceIneligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceNotEnabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            @unknown default:
                return .frameworkUnavailable
            }
        }
        #endif
        return .frameworkUnavailable
    }
}
