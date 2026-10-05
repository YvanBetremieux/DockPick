import ApplicationServices
import Foundation

/// API privée stable utilisée par la plupart des gestionnaires de fenêtres : AXUIElement → CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

extension AXUIElement {
    var pid: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(self, &pid) == .success ? pid : nil
    }

    var windowID: CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(self, &id) == .success && id != 0 ? id : nil
    }

    func copyValue(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success ? value : nil
    }

    func string(_ attribute: String) -> String? { copyValue(attribute) as? String }
    func bool(_ attribute: String) -> Bool? { copyValue(attribute) as? Bool }
    func url(_ attribute: String) -> URL? { copyValue(attribute) as? URL }
    func elements(_ attribute: String) -> [AXUIElement] { copyValue(attribute) as? [AXUIElement] ?? [] }

    func point(_ attribute: String) -> CGPoint? { Self.decodePoint(copyValue(attribute)) }
    func size(_ attribute: String) -> CGSize? { Self.decodeSize(copyValue(attribute)) }

    /// Plusieurs attributs en un seul aller-retour IPC ; nil pour chaque attribut en erreur.
    func values(_ attributes: [String]) -> [CFTypeRef?] {
        var result: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(self, attributes as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &result) == .success,
              let array = result as? [CFTypeRef], array.count == attributes.count
        else { return Array(repeating: nil, count: attributes.count) }
        return array.map { value in
            if CFGetTypeID(value) == AXValueGetTypeID(), AXValueGetType(value as! AXValue) == .axError { return nil }
            return value
        }
    }

    static func decodePoint(_ value: CFTypeRef?) -> CGPoint? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    static func decodeSize(_ value: CFTypeRef?) -> CGSize? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }

    @discardableResult
    func setBool(_ attribute: String, _ value: Bool) -> Bool {
        AXUIElementSetAttributeValue(self, attribute as CFString, (value ? kCFBooleanTrue : kCFBooleanFalse)!) == .success
    }

    @discardableResult
    func setPoint(_ attribute: String, _ point: CGPoint) -> Bool {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(self, attribute as CFString, value) == .success
    }

    @discardableResult
    func setSize(_ attribute: String, _ size: CGSize) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(self, attribute as CFString, value) == .success
    }

    @discardableResult
    func perform(_ action: String) -> Bool {
        AXUIElementPerformAction(self, action as CFString) == .success
    }
}
