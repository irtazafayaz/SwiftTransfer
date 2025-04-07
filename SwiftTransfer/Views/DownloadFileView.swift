//
//  DownloadFileView.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 26/03/2025.
//

import SwiftUI
import QuickLook

struct DownloadFileView: View {
    @StateObject private var viewModel = DownloadService()
    @State private var urlString: String = ""
    
    var body: some View {
        VStack {
            TextField("Enter file url...", text: $urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Download") {
                viewModel.errorMessage = nil
                viewModel.downloadedFilePath = nil
                viewModel.startDownload(from: urlString)
            }.buttonStyle(.borderedProminent)
            
            if viewModel.downloadProgress > 0 && viewModel.downloadProgress < 1 {
                ProgressView(value: viewModel.downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()
            }
            
            if let filePath = viewModel.downloadedFilePath {
                Text("Downloaded to: \(filePath.lastPathComponent)")
                
                Button("Open File Location") {
                    viewModel.openDownloadedFile()
                }
                .buttonStyle(.bordered)
                
                Button("Preview File") {
                    viewModel.isPreviewPresented = true
                }
                .buttonStyle(.bordered)
                .sheet(isPresented: $viewModel.isPreviewPresented) {
                    QLPreviewControllerWrapper(url: filePath)
                }
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            
            
        }
    }
}


struct QLPreviewControllerWrapper: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QLPreviewControllerWrapper
        
        init(_ parent: QLPreviewControllerWrapper) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as NSURL
        }
    }
}
