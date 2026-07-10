import Foundation
import MachO

@objc class TimeKernel: NSObject {
    
    /// Structure to hold precise timing data from the Mach kernel
    @objc struct KernelTimeResult: Codable {
        let uptimeNanoseconds: UInt64
        let absoluteTime: UInt64
        let timebaseNumerator: UInt32
        let timebaseDenominator: UInt32
        let systemBootTimeSeconds: Int64
    }

    /// Retrieves high-precision monotonic system time and timebase information.
    /// This bypasses standard Foundation wrappers to minimize overhead and jitter.
    @objc func getPreciseSystemTime() -> [String: Any] {
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        
        let absoluteTime = mach_absolute_time()
        
        // Convert mach_absolute_time to nanoseconds using the system timebase
        let uptimeNanoseconds = absoluteTime * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
        
        // Retrieve the wall clock boot time for drift calculation baseline
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var bootTime = timeval()
        var bootTimeSize = MemoryLayout<timeval>.size
        
        let result = sysctl(&mib, 2, &bootTime, &bootTimeSize, nil, 0)
        let bootTimeSeconds = (result == 0) ? Int64(bootTime.tv_sec) : 0

        return [
            "uptime_ns": uptimeNanoseconds,
            "absolute_time": absoluteTime,
            "numer": timebaseInfo.numer,
            "denom": timebaseInfo.denom,
            "boot_time_sec": bootTimeSeconds
        ]
    }

    /// Calculates the current clock frequency in Hz based on the hardware's Mach timebase
    @objc func getClockFrequency() -> Double {
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        
        // Frequency is (1e9 nanoseconds per second) * (denominator / numerator)
        let frequency = 1_000_000_000.0 * (Double(timebaseInfo.denom) / Double(timebaseInfo.numer))
        return frequency
    }

    /// Provides continuous monotonic time since the last reboot, which is 
    /// unaffected by NTP adjustments or "Time Smearing" performed by the OS.
    @objc func getContinuousTimestamp() -> Double {
        if #available(iOS 10.0, *) {
            let continuousTime = mach_continuous_time()
            var timebaseInfo = mach_timebase_info_data_t()
            mach_timebase_info(&timebaseInfo)
            
            let seconds = Double(continuousTime) * Double(timebaseInfo.numer) / Double(timebaseInfo.denom) / 1_000_000_000.0
            return seconds
        } else {
            return Double(mach_absolute_time()) / 1_000_000_000.0
        }
    }
}