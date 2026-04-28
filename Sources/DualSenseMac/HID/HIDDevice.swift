import Foundation
import IOKit
import IOKit.hid

final class HIDDevice {
    let device: IOHIDDevice
    private var inputBuffer: UnsafeMutablePointer<UInt8>
    private let inputBufferSize: Int
    private var diagPacketsLogged = 0

    var onInputReport: ((Data) -> Void)?

    init(device: IOHIDDevice, inputReportSize: Int) {
        self.device = device
        self.inputBufferSize = inputReportSize
        self.inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: inputReportSize)
        self.inputBuffer.initialize(repeating: 0, count: inputReportSize)
    }

    deinit {
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, inputBufferSize, nil, nil)
        inputBuffer.deinitialize(count: inputBufferSize)
        inputBuffer.deallocate()
    }

    func startReadingInputReports() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            device,
            inputBuffer,
            inputBufferSize,
            { ctx, _, _, _, reportID, report, reportLength in
                guard let ctx = ctx else { return }
                let me = Unmanaged<HIDDevice>.fromOpaque(ctx).takeUnretainedValue()
                let data = Data(bytes: report, count: reportLength)
                _ = reportID
                me.onInputReport?(data)
            },
            context
        )
    }

    @discardableResult
    func writeOutputReport(reportID: UInt8, data: Data) -> Bool {
        return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            let result = IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                CFIndex(reportID),
                base,
                data.count
            )
            return result == kIOReturnSuccess
        }
    }
}
