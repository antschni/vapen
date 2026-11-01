import CoreBluetooth

/// ELFA MASTER / InnoGate GATT layout and command codes — see docs/elfbar-protocol.md.
enum BleConstants {
  static let cigService = CBUUID(string: "00010203-0405-0607-0809-0A0B0C0DFF00")
  static let cigWrite = CBUUID(string: "00010203-0405-0607-0809-0A0B0C0DFF01")
  static let cigNotify = CBUUID(string: "00010203-0405-0607-0809-0A0B0C0DFF02")

  /// Firmware/theme update channel. Vapen never writes to it.
  static let otaService = CBUUID(string: "00010203-0405-0607-0809-0A0B0C0DA100")
  static let otaNotify = CBUUID(string: "00010203-0405-0607-0809-0A0B0C0DA102")

  /// iOS negotiates the ATT MTU itself; kept for parity with Android.
  static let mtuRequest = 517

  static let cmdReadIdentifier = 0x05
  static let cmdReadFirmwareVersion = 0x06
  static let cmdSetTime = 0x07
  static let cmdReadActiveState = 0x0A
  static let cmdReadLockState = 0x0B
  static let cmdReadSoc = 0x12
  static let cmdReadFuel = 0x13
  static let cmdReadSuctionTime = 0x16
  static let cmdFirstLinkInfo = 0x2A
  static let cmdReadPuffRecords = 0x33
  static let cmdReadDayPuff = 0x41

  /// Unsolicited device alert (low battery, low liquid, overheat, …).
  static let pushDeviceReport = 0x9E

  static let responseFlag = 0x80

  /// FIRST_LINK_INFO platform byte. Only the Android value (0x02) is confirmed from InnoGate's
  /// Android build; iOS sends it too until the InnoGate iOS value is verified on hardware.
  static let identifierTypeAndroid = 0x02

  static let nameHints = ["elfa", "master", "elfbar", "innogate"]
}
