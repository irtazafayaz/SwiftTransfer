//
//  DownloadListView.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 14/08/2025.
//

import SwiftUI

struct DownloadListView: View {
    @StateObject private var viewModel = DownloadViewModel()
    @State private var urlText: String = "https://icrrd.com/public/media/15-05-2021-084550The-Alchemist-Paulo-Coelho.pdf"
    
    var body: some View {
        VStack {
            HStack {
                TextField("Enter file URL...", text: $urlText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Add") {
                    guard !urlText.isEmpty else { return }
                    viewModel.addDownload(urlString: urlText)
                    urlText = ""
                }
            }
            .padding()
            
            List {
                ForEach(viewModel.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.url.lastPathComponent).font(.headline)

                        if let p = item.progress {
                            ProgressView(value: p)
                        } else {
                            ProgressView()
                        }

                        HStack {
                            Text(item.status).font(.caption).foregroundColor(.gray)
                            Spacer()
                            if item.status == "Downloading" {
                                Button("Cancel") { viewModel.cancelDownload(id: item.id) }
                                    .foregroundColor(.red)
                            }
                        }

                        if let error = item.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)


                }
            }
        }
    }
}
