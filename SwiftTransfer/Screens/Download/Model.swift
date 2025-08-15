//
//  Model.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 14/08/2025.
//

import Foundation

struct DownloadItem: Identifiable {
    let id: UUID
    let url: URL
    var progress: Double? = nil
    var status: String = "Queued"
    var errorMessage: String? = nil  // <— show this in UI
}

