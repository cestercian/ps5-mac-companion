import Foundation
import IOKit
import IOKit.hid

enum DualSenseTransport {
    case usb
    case bluetooth
}

final class DualSenseManager {
    static let vendorID: UInt32 = 0x054C
    static let productID: UInt32 = 0x0CE6
    static let usbInputReportSize = 64
    static let usbOutputReportID: UInt8 = 0x02
    static let usbOutputReportSize = 47

    private let manager: IOHIDManager
    private(set) var connected: HIDDevice?

    var onConnect: ((HIDDevice, DualSenseTransport) -> Void)?
    var onDisconnect: (() -> Void)?

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // Explicit NSNumber so the values are correctly bridged into CFNumber for the
        // IOKit matching dictionary. A bare UInt32 inside [String: Any] does NOT
        // round-trip through CFDictionary correctly on every Swift version.
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: NSNumber(value: Self.vendorID),
            kIOHIDProductIDKey: NSNumber(value: Self.productID)
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    func start() {
        NSLog("DualSenseManager: start() — registering callbacks and opening manager")
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            { ctx, _, _, device in
                guard let ctx = ctx else { return }
                let me = Unmanaged<DualSenseManager>.fromOpaque(ctx).takeUnretainedValue()
                me.handleMatched(device: device)
            },
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            { ctx, _, _, _ in
                guard let ctx = ctx else { return }
                let me = Unmanaged<DualSenseManager>.fromOpaque(ctx).takeUnretainedValue()
                me.handleRemoved()
            },
            context
        )
        // Don't seize — seize blocks GameController.framework from writing
        // (which is the only API path macOS 26 honors for lightbar AND triggers).
        // Raw HID still works for rumble.
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        NSLog("DualSenseManager: IOHIDManagerOpen result = 0x%x (%@)",
              openResult, openResult == kIOReturnSuccess ? "success" : "FAILED")

        // Belt-and-suspenders: also enumerate already-connected devices, in case
        // the matching callback doesn't fire for devices that were already attached.
        if let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            NSLog("DualSenseManager: %d already-attached matching device(s)", set.count)
            for device in set {
                handleMatched(device: device)
            }
        } else {
            NSLog("DualSenseManager: IOHIDManagerCopyDevices returned nil/empty")
        }
    }

    private func handleMatched(device: IOHIDDevice) {
        let transport = Self.detectTransport(for: device)
        let reportSize = transport == .usb ? Self.usbInputReportSize : 78
        let hid = HIDDevice(device: device, inputReportSize: reportSize)
        hid.startReadingInputReports()
        connected = hid
        NSLog("DualSenseManager: connected via %@ (input report %d bytes)",
              transport == .usb ? "USB" : "Bluetooth", reportSize)
        onConnect?(hid, transport)
    }

    private func handleRemoved() {
        NSLog("DualSenseManager: disconnected")
        connected = nil
        onDisconnect?()
    }

    private static func detectTransport(for device: IOHIDDevice) -> DualSenseTransport {
        guard let raw = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) else {
            return .usb
        }
        let transport = (raw as? String) ?? ""
        if transport.lowercased().contains("bluetooth") {
            return .bluetooth
        }
        return .usb
    }
}
