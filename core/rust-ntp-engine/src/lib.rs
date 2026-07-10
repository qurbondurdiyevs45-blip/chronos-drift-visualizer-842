use std::net::UdpSocket;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct NtpResult {
    pub offset_nanos: i64,
    pub delay_nanos: u64,
    pub stratum: u8,
    pub precision: i8,
    pub root_delay_nanos: u64,
}

#[repr(C)]
#[derive(Default)]
struct NtpPacket {
    li_vn_mode: u8,
    stratum: u8,
    poll: i8,
    precision: i8,
    root_delay: u32,
    root_dispersion: u32,
    ref_id: u32,
    ref_timestamp: u64,
    orig_timestamp: u64,
    recv_timestamp: u64,
    trans_timestamp: u64,
}

impl NtpPacket {
    fn new() -> Self {
        let mut packet = NtpPacket::default();
        // LI = 0 (no warning), VN = 4 (IPv4), Mode = 3 (Client)
        packet.li_vn_mode = (0 << 6) | (4 << 3) | 3;
        packet
    }

    fn to_bytes(&self) -> [u8; 48] {
        let mut buf = [0u8; 48];
        buf[0] = self.li_vn_mode;
        buf[1] = self.stratum;
        buf[2] = self.poll as u8;
        buf[3] = self.precision as u8;
        // Big-endian conversion for timestamps
        buf[40..48].copy_from_slice(&self.trans_timestamp.to_be_bytes());
        buf
    }

    fn from_bytes(buf: &[u8; 48]) -> Self {
        NtpPacket {
            li_vn_mode: buf[0],
            stratum: buf[1],
            poll: buf[2] as i8,
            precision: buf[3] as i8,
            root_delay: u32::from_be_bytes(buf[4..8].try_into().unwrap()),
            root_dispersion: u32::from_be_bytes(buf[8..12].try_into().unwrap()),
            ref_id: u32::from_be_bytes(buf[12..16].try_into().unwrap()),
            ref_timestamp: u64::from_be_bytes(buf[16..24].try_into().unwrap()),
            orig_timestamp: u64::from_be_bytes(buf[24..32].try_into().unwrap()),
            recv_timestamp: u64::from_be_bytes(buf[32..40].try_into().unwrap()),
            trans_timestamp: u64::from_be_bytes(buf[40..48].try_into().unwrap()),
        }
    }
}

fn ntp_to_nanos(ntp_val: u64) -> u64 {
    let seconds = (ntp_val >> 32) * 1_000_000_000;
    let fraction = ((ntp_val & 0xFFFF_FFFF) * 1_000_000_000) >> 32;
    seconds + fraction
}

fn get_system_ntp_time() -> u64 {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap();
    let seconds = now.as_secs() + 2_208_988_800; // NTP Epoch offset
    let fractional = ((now.subsec_nanos() as u64) << 32) / 1_000_000_000;
    (seconds << 32) | fractional
}

pub fn get_drift(address: &str) -> Result<NtpResult, String> {
    let socket = UdpSocket::bind("0.0.0.0:0").map_err(|e| e.to_string())?;
    socket.set_read_timeout(Some(Duration::from_secs(3))).map_err(|e| e.to_string())?;

    let mut packet = NtpPacket::new();
    let t1 = get_system_ntp_time();
    packet.trans_timestamp = t1;

    socket.send_to(&packet.to_bytes(), address).map_err(|e| e.to_string())?;

    let mut response_buf = [0u8; 48];
    let (_, _) = socket.recv_from(&mut response_buf).map_err(|e| e.to_string())?;
    let t4 = get_system_ntp_time();

    let response = NtpPacket::from_bytes(&response_buf);
    
    let t1_ns = ntp_to_nanos(t1) as i128;
    let t2_ns = ntp_to_nanos(response.recv_timestamp) as i128;
    let t3_ns = ntp_to_nanos(response.trans_timestamp) as i128;
    let t4_ns = ntp_to_nanos(t4) as i128;

    // Standard NTP Offset Calculation: ((t2 - t1) + (t3 - t4)) / 2
    let offset_nanos = ((t2_ns - t1_ns) + (t3_ns - t4_ns)) / 2;
    
    // Round trip delay Calculation: (t4 - t1) - (t3 - t2)
    let delay_nanos = (t4_ns - t1_ns) - (t3_ns - t2_ns);

    Ok(NtpResult {
        offset_nanos: offset_nanos as i64,
        delay_nanos: delay_nanos as u64,
        stratum: response.stratum,
        precision: response.precision,
        root_delay_nanos: (ntp_to_nanos(response.root_delay as u64) >> 16),
    })
}

#[no_mangle]
pub extern "C" fn calculate_drift_ffi(addr_ptr: *const i8) -> *mut NtpResult {
    use std::ffi::CStr;
    
    let c_str = unsafe { CStr::from_ptr(addr_ptr) };
    let addr = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    match get_drift(addr) {
        Ok(res) => Box::into_raw(Box::new(res)),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn free_ntp_result(ptr: *mut NtpResult) {
    if !ptr.is_null() {
        unsafe { Box::from_raw(ptr); }
    }
}