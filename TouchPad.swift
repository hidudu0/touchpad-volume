// 터치패드 음량
// 트랙패드에 네 손가락 올리고 위/아래로 쓸면 음량 조절. 네 손가락일 땐 스크롤 막음.
// 화면에 보이는 것 없음. 끄기: pkill touchpad / 자동 실행 끄기: 시스템 설정 → 일반 → 로그인 항목
import AudioToolbox
import Cocoa
import ServiceManagement
import Synchronization

let gain = 1.5     // ponytail: 쓸은 거리(트랙패드 높이 = 1) × gain = 음량 변화. 너무 빠르거나 느리면 조정
let flipY = false  // ponytail: 기기에서 위아래가 반대로 먹으면 true

// 좌우로 더 많이 움직였으면 nil → 네 손가락 좌우 스와이프(화면 전환)는 무시
func swipeVolume(_ v0: Double, dx: Double, dy: Double) -> Double? {
    abs(dy) > abs(dx) ? min(max(v0 + dy * gain, 0), 1) : nil
}

// 네 손가락이면 스크롤 막음. 손 뗀 뒤 이어지는 관성 스크롤은 직전 판단을 따름
func blocksScroll(fingers: Int, momentum: Bool, wasBlocking: Bool) -> Bool {
    momentum ? wasBlocking : fingers == 4
}

// MARK: 비공개 프레임워크 (MultitouchSupport: 손가락 절대좌표)

struct MTPoint { var x, y: Float }
struct MTReadout { var pos, vel: MTPoint }
struct Finger {
    var frame: Int32; var timestamp: Double
    var identifier, state, foo3, foo4: Int32
    var normalized: MTReadout
    var size: Float; var zero1: Int32
    var angle, majorAxis, minorAxis: Float
    var mm: MTReadout
    var zero2a, zero2b: Int32
    var unk2: Float
}
typealias MTCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32

func sym<T>(_ lib: String, _ name: String, _: T.Type) -> T? {
    dlsym(dlopen("/System/Library/PrivateFrameworks/\(lib).framework/\(lib)", RTLD_NOW), name).map { unsafeBitCast($0, to: T.self) }
}

// MARK: 음량 (CoreAudio: AppleScript는 한 번에 16ms + 매번 XProtect 검사라 메인 스레드가 밀림)

// 기본 출력 장치는 매번 새로 읽음 → 이어폰 꽂거나 출력 바꿔도 따라감
func output(_ selector: AudioObjectPropertySelector) -> (AudioObjectID, AudioObjectPropertyAddress) {
    var dev = AudioObjectID(0), size = UInt32(MemoryLayout<AudioObjectID>.size)
    var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                       mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &dev)
    return (dev, AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain))
}

func volumeNow() -> Double {
    var (dev, a) = output(kAudioHardwareServiceDeviceProperty_VirtualMainVolume), v = Float32(0), size = UInt32(4)
    AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &v)
    return Double(v)
}

var percent = -1
func setVolume(_ v: Double) {
    let p = Int((v * 100).rounded())
    guard p != percent else { return }
    percent = p
    var (dev, a) = output(kAudioHardwareServiceDeviceProperty_VirtualMainVolume), x = Float32(p) / 100
    AudioObjectSetPropertyData(dev, &a, 0, nil, 4, &x)
    var (_, m) = output(kAudioDevicePropertyMute), off = UInt32(0)  // 쓸면 음소거 풀림
    AudioObjectSetPropertyData(dev, &m, 0, nil, 4, &off)
}

// MARK: 터치 처리

struct Swipe { let ids: Set<Int32>; let x0, y0, v0: Double }
var swipe: Swipe?

func handle(_ touches: [(id: Int32, x: Double, y: Double)]) {
    guard touches.count == 4 else { swipe = nil; return }
    let ids = Set(touches.map(\.id))
    let x = touches.map(\.x).reduce(0, +) / 4, y = touches.map(\.y).reduce(0, +) / 4
    guard let s = swipe, s.ids == ids else {  // 네 손가락 막 닿음 → 지금 위치·음량이 기준
        let v0 = volumeNow()
        swipe = Swipe(ids: ids, x0: x, y0: y, v0: v0)
        percent = Int((v0 * 100).rounded())
        return
    }
    if let v = swipeVolume(s.v0, dx: x - s.x0, dy: y - s.y0) { setVolume(v) }
}

let fingerCount = Atomic<Int>(0)  // 트랙패드 스레드에서 쓰고 이벤트 탭에서 읽음

let touchCallback: MTCallback = { _, data, n, _, _ in
    guard let data else { return 0 }
    let fingers = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Finger.self), count: Int(n))
    let touches = fingers.filter { $0.state == 3 || $0.state == 4 }.map {
        (id: $0.identifier, x: Double($0.normalized.pos.x), y: Double(flipY ? 1 - $0.normalized.pos.y : $0.normalized.pos.y))
    }
    fingerCount.store(touches.count, ordering: .relaxed)  // 스크롤 이벤트보다 늦지 않게 바로 기록
    DispatchQueue.main.async { handle(touches) }
    return 0
}

// MARK: 스크롤 차단 (이벤트 탭, 손쉬운 사용 권한 필요)

var tap: CFMachPort?
var blockingScroll = false

let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    blockingScroll = blocksScroll(fingers: fingerCount.load(ordering: .relaxed),
                                  momentum: event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0,
                                  wasBlocking: blockingScroll)
    return blockingScroll ? nil : Unmanaged.passUnretained(event)
}

func installTap() -> Bool {
    guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                    eventsOfInterest: CGEventMask(1) << CGEventType.scrollWheel.rawValue,
                                    callback: tapCallback, userInfo: nil) else { return false }
    tap = t
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
    return true
}

// MARK: 자체 점검: ./touchpad --test

if CommandLine.arguments.contains("--test") {
    precondition(MemoryLayout<Finger>.stride == 96)
    precondition((0...1).contains(volumeNow()))  // 읽기만 함, 음량 안 바꿈
    precondition(swipeVolume(0.5, dx: 0, dy: 0.1)! > 0.5 && swipeVolume(0.5, dx: 0.02, dy: -0.1)! < 0.5)
    precondition(swipeVolume(0.9, dx: 0, dy: 5) == 1 && swipeVolume(0.1, dx: 0, dy: -5) == 0)
    precondition(swipeVolume(0.5, dx: 0.2, dy: 0.1) == nil && swipeVolume(0.5, dx: 0, dy: 0) == nil)
    precondition(blocksScroll(fingers: 4, momentum: false, wasBlocking: false) && !blocksScroll(fingers: 3, momentum: false, wasBlocking: true))
    precondition(blocksScroll(fingers: 0, momentum: true, wasBlocking: true) && !blocksScroll(fingers: 4, momentum: true, wasBlocking: false))
    print("ok")
    exit(0)
}

// MARK: 실행

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

typealias MTDevice = UnsafeMutableRawPointer
let mtCreate = sym("MultitouchSupport", "MTDeviceCreateDefault", (@convention(c) () -> MTDevice?).self)
let mtRegister = sym("MultitouchSupport", "MTRegisterContactFrameCallback", (@convention(c) (MTDevice, MTCallback) -> Void).self)
let mtStart = sym("MultitouchSupport", "MTDeviceStart", (@convention(c) (MTDevice, Int32) -> Int32).self)
let mtStop = sym("MultitouchSupport", "MTDeviceStop", (@convention(c) (MTDevice) -> Void).self)
var device: MTDevice?

// 잠자기에서 깨면 트랙패드 신호가 끊길 수 있음 → 장치를 새로 열어 다시 연결
func startTouch() {
    if let device { mtStop?(device) }
    device = nil
    guard let mtCreate, let mtRegister, let mtStart, let d = mtCreate() else { NSLog("트랙패드 못 찾음"); return }
    mtRegister(d, touchCallback)
    _ = mtStart(d, 0)
    device = d
}
startTouch()
NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { startTouch() }  // ponytail: 깬 직후 장치 준비 시간 2초로 가정
}

// 손쉬운 사용 권한 요청 → 허용될 때까지 2초마다 탭 설치 재시도
_ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
if !installTap() {
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { if installTap() { $0.invalidate() } }
}

// 로그인하면 자동 실행. 처음 한 번만 등록 → 시스템 설정 → 일반 → 로그인 항목에서 끄면 그대로 둠
if !UserDefaults.standard.bool(forKey: "loginItemRegistered") {
    do {
        try SMAppService.mainApp.register()
        UserDefaults.standard.set(true, forKey: "loginItemRegistered")
    } catch { NSLog("로그인 항목 등록 실패: \(error)") }
}

app.run()
