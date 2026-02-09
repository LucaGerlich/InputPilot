import Foundation
import IOKit.hid

final class PermissionService {
    func checkInputMonitoring() -> IOHIDAccessType {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    }

    func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    var isGranted: Bool {
        checkInputMonitoring() == kIOHIDAccessTypeGranted
    }
}
