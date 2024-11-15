//
//  QRCodeSettings.swift
//  qrcode_reading
//
//  Created by Matheus Felipe on 15/11/24.
//

import Foundation

struct QRCodeSettings {
    let pauseReading: Bool
    let isFlashLightOn: Bool
    
    init?(from args: [String: Any]) {
        guard let pauseReading = args["pauseReading"] as? Bool,
              let isFlashLightOn = args["isFlashLightOn"] as? Bool else {
            return nil
        }
        self.pauseReading = pauseReading
        self.isFlashLightOn = isFlashLightOn
    }
}
