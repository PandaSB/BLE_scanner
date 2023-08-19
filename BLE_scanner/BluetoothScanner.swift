//
//  BluetoothScanner.swift
//  BLE_scanner
//
//  Created by Stephane BARTHELEMY on 27/07/2023.
//

import SwiftUI
import CoreBluetooth

enum DeviceType {
    case eNone
    case eLovense
    case exiaomi
    case ehuami
    case eOther
    
    var stringValue : String {
      switch self {
      // Use Internationalization, as appropriate.
      case .eNone: return "None"
      case .eLovense: return "Lovense"
      case .exiaomi: return "Xiaomi"
      case .ehuami: return "Huami"
      case .eOther: return "Other"
      }
    }
}


struct DiscoveredPeripheral {
    // Struct to represent a discovered peripheral
    var peripheral: CBPeripheral
    var advertisedData: String
    var rssi: NSNumber
    var uuid: String
    var serviceuuid: String
    var devicetype: DeviceType
    var connected: Bool
}

class BluetoothScanner: NSObject, CBCentralManagerDelegate, ObservableObject, CBPeripheralDelegate {
    @Published var discoveredPeripherals = [DiscoveredPeripheral]()
    @Published var isScanning = false
    var centralManager: CBCentralManager!
    var discoveredPeripheralSet = Set<CBPeripheral>()
    var timer: Timer?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

  
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            //print("central.state is .unknown")
            stopScan()
        case .resetting:
            //print("central.state is .resetting")
            stopScan()
        case .unsupported:
            //print("central.state is .unsupported")
            stopScan()
        case .unauthorized:
            //print("central.state is .unauthorized")
            stopScan()
        case .poweredOff:
            //print("central.state is .poweredOff")
            stopScan()
        case .poweredOn:
            //print("central.state is .poweredOn")
            startScan()
        @unknown default:
            print("central.state is unknown")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
      peripheral.delegate = self
      guard let services = peripheral.services else { return }
      for service in services {
        print(service)
        peripheral.discoverCharacteristics(nil, for: service)
      }
    }
    
    func peripheral( _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,error: Error? )
    {
        print("Found \(service.characteristics!.count) characteristics!: \(String(describing: service.characteristics))")

    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        if discoveredPeripheralSet.contains(peripheral) {
            if let index = discoveredPeripherals.firstIndex(where: { $0.peripheral == peripheral }) {
                discoveredPeripherals[index].connected = true
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Build a string representation of the advertised data and sort it by names
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        var advertisedData = advertisementData.map { "\($0): \($1)" }.sorted(by: { $0 < $1 }).joined(separator: "\n")

        // Convert the timestamp into human readable format and insert it to the advertisedData String
        let timestampValue = advertisementData["kCBAdvDataTimestamp"] as! Double
 
        // print(timestampValue)
        let dateFormatter = DateFormatter()
        let uuid: String
        var devicetype = DeviceType.eNone
        uuid = peripheral.identifier.uuidString
        dateFormatter.dateFormat = "HH:mm:ss"
        let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: timestampValue))
        advertisedData = "actual rssi: \(RSSI) dB\n" + "Timestamp: \(dateString)\n" + advertisedData
        var serviceuuid = ""
        let suuids = advertisementData["kCBAdvDataServiceUUIDs"] as? [CBUUID] ?? []
        for uniqueID in suuids {
            serviceuuid = uniqueID.uuidString
            if  serviceuuid .contains("50300001-0023-4BD4-BBD5-A6920E4C5653") ||
                    serviceuuid .contains("54300001-0023-4BD4-BBD5-A6920E4C5653") {
                devicetype = DeviceType.eLovense
            } else if  serviceuuid .contains("FE95") {
                devicetype = DeviceType.exiaomi
            } else if  serviceuuid .contains("FEE0") ||
                        serviceuuid .contains("FEE1")
            {
                devicetype = DeviceType.ehuami
            }
            
        }

        let ServiceData = advertisementData["kCBAdvDataServiceData"] as? [CBUUID] ?? []
        for uniqueID in ServiceData {
            serviceuuid = uniqueID.uuidString
            if  serviceuuid .contains("50300001-0023-4BD4-BBD5-A6920E4C5653") ||
                    serviceuuid .contains("54300001-0023-4BD4-BBD5-A6920E4C5653") {
                devicetype = DeviceType.eLovense
            } else if  serviceuuid .contains("FE95") {
                devicetype = DeviceType.exiaomi
            } else if  serviceuuid .contains("FEE0") ||
                        serviceuuid .contains("FEE1")
            {
                devicetype = DeviceType.ehuami
            }
            
        }
        
        
        
        // If the peripheral is not already in the list
        if !discoveredPeripheralSet.contains(peripheral) {
            // Add it to the list and the set
            discoveredPeripherals.append(DiscoveredPeripheral(peripheral: peripheral, advertisedData: advertisedData, rssi: RSSI, uuid: uuid, serviceuuid: serviceuuid,devicetype: devicetype, connected: false))
            discoveredPeripheralSet.insert(peripheral)
            objectWillChange.send()
        } else {
            // If the peripheral is already in the list, update its advertised data
            if let index = discoveredPeripherals.firstIndex(where: { $0.peripheral == peripheral }) {
                discoveredPeripherals[index].advertisedData = advertisedData
                discoveredPeripherals[index].rssi = RSSI
                discoveredPeripherals[index].uuid = uuid
                discoveredPeripherals[index].serviceuuid = serviceuuid
                discoveredPeripherals[index].devicetype = devicetype
                objectWillChange.send()
            }
        }
    }
    
    func startScan() {
        if centralManager.state == .poweredOn {
            // Set isScanning to true and clear the discovered peripherals list
            isScanning = true
            discoveredPeripherals.removeAll()
            discoveredPeripheralSet.removeAll()
            objectWillChange.send()

            // Start scanning for peripherals
            centralManager.scanForPeripherals(withServices: nil)

            // Start a timer to stop and restart the scan every 2 seconds
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                self?.centralManager.stopScan()
                self?.centralManager.scanForPeripherals(withServices: nil)
            }
        }
    }

    func stopScan() {
        // Set isScanning to false and stop the timer
        isScanning = false
        timer?.invalidate()
        centralManager.stopScan()
    }
    
    func connect ( peripheral: CBPeripheral) {
        if discoveredPeripheralSet.contains(peripheral) {
            if let index = discoveredPeripherals.firstIndex(where: { $0.peripheral == peripheral }) {
                print(peripheral)
                let connectPeripheral : CBPeripheral = peripheral
                connectPeripheral.delegate = self
                self.stopScan()
                centralManager.connect(connectPeripheral)
            }
        }
    }
    
    
    func disconnect ( peripheral: CBPeripheral) {
        if discoveredPeripheralSet.contains(peripheral) {
            if let index = discoveredPeripherals.firstIndex(where: { $0.peripheral == peripheral }) {
                print(peripheral)
                let connectPeripheral : CBPeripheral = peripheral
                connectPeripheral.delegate = self
                self.stopScan()
                centralManager.cancelPeripheralConnection(connectPeripheral)
                
                discoveredPeripherals[index].connected = false
               }
        }
    }


}
