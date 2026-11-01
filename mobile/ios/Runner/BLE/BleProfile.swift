import CoreBluetooth

struct BleProfile {
  let name: String
  let serviceUuid: CBUUID
  /// Phone → device (framed commands, write with response).
  let txUuid: CBUUID
  /// Device → phone (responses and pushes, notify).
  let rxUuid: CBUUID
  /// Notify characteristic InnoGate subscribes to as well; optional.
  var otaNotify: (service: CBUUID, characteristic: CBUUID)? = nil
}

enum BleProfileDetector {
  /// Expects services and their characteristics to be discovered already.
  static func detect(_ peripheral: CBPeripheral) -> BleProfile? {
    guard let services = peripheral.services,
          let cig = services.first(where: { $0.uuid == BleConstants.cigService }),
          let characteristics = cig.characteristics,
          characteristics.contains(where: { $0.uuid == BleConstants.cigWrite }),
          characteristics.contains(where: { $0.uuid == BleConstants.cigNotify })
    else { return nil }
    let ota = services.first(where: { $0.uuid == BleConstants.otaService })?
      .characteristics?
      .first(where: { $0.uuid == BleConstants.otaNotify })
      .map { _ in (service: BleConstants.otaService, characteristic: BleConstants.otaNotify) }
    return BleProfile(
      name: "innogate_cig",
      serviceUuid: BleConstants.cigService,
      txUuid: BleConstants.cigWrite,
      rxUuid: BleConstants.cigNotify,
      otaNotify: ota
    )
  }
}
