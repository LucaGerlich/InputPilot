import Foundation
import Carbon
#if DEBUG
import OSLog
#endif

final class InputSourceService: InputSourceServicing {
#if DEBUG
    private let logger = Logger(subsystem: "InputPilot", category: "InputSourceService")
#endif

    func listEnabledInputSources() -> [InputSourceInfo] {
        let filter: [String: Any] = [
            kTISPropertyInputSourceIsEnabled as String: kCFBooleanTrue as Any
        ]
        return makeInputSourceInfos(from: inputSources(matching: filter))
    }

    func listAllInputSources() -> [InputSourceInfo] {
        makeInputSourceInfos(from: inputSources(matching: nil))
    }

    func existsEnabledInputSource(id: String) -> Bool {
        let filter: [String: Any] = [
            kTISPropertyInputSourceIsEnabled as String: kCFBooleanTrue as Any,
            kTISPropertyInputSourceID as String: id
        ]
        return !inputSources(matching: filter).isEmpty
    }

    func currentInputSourceId() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        return stringProperty(for: source, key: kTISPropertyInputSourceID)
    }

    func selectInputSource(id: String) -> Bool {
        let filter: [String: Any] = [
            kTISPropertyInputSourceID as String: id
        ]

        guard let source = inputSources(matching: filter).first else {
            debugLog("No input source found for id=\(id)")
            return false
        }

        guard boolProperty(for: source, key: kTISPropertyInputSourceIsSelectCapable) else {
            debugLog("Input source is not selectable. id=\(id)")
            return false
        }

        let result = TISSelectInputSource(source)
        guard result == noErr else {
            debugLog("TISSelectInputSource failed for id=\(id), result=\(result)")
            return false
        }

        debugLog("Selected input source id=\(id)")
        return true
    }

    private func makeInputSourceInfos(from sources: [TISInputSource]) -> [InputSourceInfo] {
        var infos: [InputSourceInfo] = []

        for source in sources {
            guard let id = stringProperty(for: source, key: kTISPropertyInputSourceID) else {
                continue
            }

            let name = stringProperty(for: source, key: kTISPropertyLocalizedName) ?? id
            let isSelectable = boolProperty(for: source, key: kTISPropertyInputSourceIsSelectCapable)
            infos.append(InputSourceInfo(id: id, name: name, isSelectable: isSelectable))
        }

        return infos.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func inputSources(matching filter: [String: Any]?) -> [TISInputSource] {
        guard let unmanagedList = TISCreateInputSourceList(filter as CFDictionary?, false) else {
            return []
        }

        let list = unmanagedList.takeRetainedValue() as NSArray
        return list.map { $0 as! TISInputSource }
    }

    private func propertyValue(for source: TISInputSource, key: CFString) -> CFTypeRef? {
        guard let rawProperty = TISGetInputSourceProperty(source, key) else {
            return nil
        }

        return unsafeBitCast(rawProperty, to: CFTypeRef.self)
    }

    private func stringProperty(for source: TISInputSource, key: CFString) -> String? {
        guard let value = propertyValue(for: source, key: key) else {
            return nil
        }

        if CFGetTypeID(value) == CFStringGetTypeID() {
            return value as? String
        }

        return nil
    }

    private func boolProperty(for source: TISInputSource, key: CFString) -> Bool {
        guard let value = propertyValue(for: source, key: key) else {
            return false
        }

        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((value as! CFBoolean))
        }

        return false
    }

    private func debugLog(_ message: String) {
#if DEBUG
        logger.debug("\(message, privacy: .public)")
#endif
    }
}
