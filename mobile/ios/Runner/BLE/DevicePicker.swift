import CoreBluetooth
import UIKit

/// iOS stand-in for Android's Companion Device Manager: scans for ELFA MASTER advertisements and
/// lets the user pick one from an action sheet. Main thread only.
final class DevicePicker: NSObject {
  enum Outcome {
    case picked(address: String)
    case failed(String)
  }

  private struct Candidate {
    let peripheral: CBPeripheral
    let name: String
    let rssi: Int?
  }

  private var central: CBCentralManager?
  private var candidates: [UUID: Candidate] = [:]
  private var completion: ((Outcome) -> Void)?
  private var presentWork: DispatchWorkItem?
  private var timeoutWork: DispatchWorkItem?
  private let presenter: () -> UIViewController?

  init(presenter: @escaping () -> UIViewController?) {
    self.presenter = presenter
  }

  func pick(completion: @escaping (Outcome) -> Void) {
    finish(.failed("Kopplung abgebrochen"))
    self.completion = completion
    candidates = [:]
    let created = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    central = created
    if created.state == .poweredOn { startScan(created) }
  }

  private func startScan(_ central: CBCentralManager) {
    // Already connected to iOS (e.g. by InnoGate) devices do not advertise.
    for peripheral in central.retrieveConnectedPeripherals(withServices: [BleConstants.cigService]) {
      add(peripheral, name: peripheral.name ?? "ELFA MASTER", rssi: nil)
    }
    central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    let timeout = DispatchWorkItem { [weak self] in
      self?.finish(.failed("Keine Elfbar gefunden — Display einschalten, InnoGate schließen und erneut versuchen."))
    }
    timeoutWork = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.scanTimeout, execute: timeout)
    if !candidates.isEmpty { schedulePresentation() }
  }

  private func add(_ peripheral: CBPeripheral, name: String, rssi: Int?) {
    let known = candidates[peripheral.identifier]
    candidates[peripheral.identifier] = Candidate(peripheral: peripheral, name: name, rssi: rssi ?? known?.rssi)
    schedulePresentation()
  }

  /// Waits briefly after the first hit so several nearby devices can show up in one list.
  private func schedulePresentation() {
    guard presentWork == nil else { return }
    let work = DispatchWorkItem { [weak self] in self?.present() }
    presentWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.collectDelay, execute: work)
  }

  private func present() {
    central?.stopScan()
    timeoutWork?.cancel()
    guard let host = presenter() else {
      finish(.failed("Geräteauswahl konnte nicht angezeigt werden."))
      return
    }
    let sheet = UIAlertController(
      title: "Elfbar auswählen",
      message: "Elfbar Master in der Liste auswählen.",
      preferredStyle: .actionSheet
    )
    let sorted = candidates.values.sorted { ($0.rssi ?? 0) > ($1.rssi ?? 0) }
    for candidate in sorted {
      let label = candidate.rssi.map { "\(candidate.name) (\($0) dBm)" } ?? "\(candidate.name) (verbunden)"
      sheet.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
        self?.finish(.picked(address: candidate.peripheral.identifier.uuidString))
      })
    }
    sheet.addAction(UIAlertAction(title: "Abbrechen", style: .cancel) { [weak self] _ in
      self?.finish(.failed("Kopplung abgebrochen"))
    })
    if let popover = sheet.popoverPresentationController {
      popover.sourceView = host.view
      popover.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 0, height: 0)
      popover.permittedArrowDirections = []
    }
    host.present(sheet, animated: true)
  }

  private func finish(_ outcome: Outcome) {
    presentWork?.cancel()
    presentWork = nil
    timeoutWork?.cancel()
    timeoutWork = nil
    if let central, central.state == .poweredOn { central.stopScan() }
    central?.delegate = nil
    central = nil
    let callback = completion
    completion = nil
    callback?(outcome)
  }

  private static let scanTimeout: TimeInterval = 20
  private static let collectDelay: TimeInterval = 2.5
}

extension DevicePicker: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard central === self.central else { return }
    switch central.state {
    case .poweredOn:
      startScan(central)
    case .unauthorized:
      finish(.failed("Bluetooth-Berechtigung fehlt — in den iOS-Einstellungen für Vapen erlauben."))
    case .poweredOff:
      finish(.failed("Bluetooth ist aus — bitte einschalten."))
    case .unsupported:
      finish(.failed("Bluetooth LE wird auf diesem Gerät nicht unterstützt."))
    default:
      break
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
    guard let name, presentWork != nil || completion != nil else { return }
    let lowered = name.lowercased()
    guard BleConstants.nameHints.contains(where: { lowered.contains($0) }) else { return }
    add(peripheral, name: name, rssi: RSSI.intValue)
  }
}

extension UIApplication {
  /// Topmost view controller of the key window, for presenting native UI over Flutter.
  var vapenTopViewController: UIViewController? {
    let windows = connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
