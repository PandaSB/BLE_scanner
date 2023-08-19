//
//  ContentView.swift
//  BLE_scanner
//
//  Created by Stephane BARTHELEMY on 27/07/2023.
//

import SwiftUI
import CoreBluetooth


struct ContentView: View {
    @ObservedObject private var bluetoothScanner = BluetoothScanner()
    @State private var searchText = ""

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            
            HStack {
                 // Text field for entering search text
                 TextField("Search", text: $searchText)
                     .textFieldStyle(RoundedBorderTextFieldStyle())

                 // Button for clearing search text
                 Button(action: {
                     self.searchText = ""
                 }) {
                     Image(systemName: "xmark.circle.fill")
                         .foregroundColor(.secondary)
                 }
                 .buttonStyle(PlainButtonStyle())
                 .opacity(searchText == "" ? 0 : 1)
             }
             .padding()

            
            
            // List of discovered peripherals filtered by search text
            List(bluetoothScanner.discoveredPeripherals.filter {
                self.searchText.isEmpty ? true : $0.peripheral.name?.lowercased().contains(self.searchText.lowercased()) == true
            }, id: \.peripheral.identifier) { discoveredPeripheral in
                VStack(alignment: .leading) {
                    Text(discoveredPeripheral.peripheral.name ?? "Unknown Device")
                    Text(discoveredPeripheral.uuid)
                        .font(.caption)
                        .foregroundColor(.white)
                    Text(discoveredPeripheral.serviceuuid)
                        .font(.caption)
                        .foregroundColor(.gray)

                    HStack {
                        
                        Button(action: {
                            if !discoveredPeripheral.connected {
                                self.bluetoothScanner.connect(peripheral: discoveredPeripheral.peripheral)
                            } else {
                                self.bluetoothScanner.disconnect(peripheral: discoveredPeripheral.peripheral)

                            }
                        }) {
                            if !discoveredPeripheral.connected {
                                Text("Connect")
                            } else {
                                Text("Disconnect")

                            }
                            
                        }
                        .padding()
                        .background(discoveredPeripheral.connected ? Color.red : Color.blue)
                        .foregroundColor(Color.white)
                        .cornerRadius(5.0)
                    
                        VStack(alignment: .leading) {
                           Text(discoveredPeripheral.devicetype.stringValue)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(discoveredPeripheral.advertisedData)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                }

            }

            // Button for starting or stopping scanning
            Button(action: {
                if self.bluetoothScanner.isScanning {
                    self.bluetoothScanner.stopScan()
                } else {
                    self.bluetoothScanner.startScan()
                }
            }) {
                if bluetoothScanner.isScanning {
                    Text("Stop Scanning")
                } else {
                    Text("Scan for Devices")
                }
            }
            // Button looks cooler this way on iOS
            .padding()
            .background(bluetoothScanner.isScanning ? Color.red : Color.blue)
            .foregroundColor(Color.white)
            .cornerRadius(5.0)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
