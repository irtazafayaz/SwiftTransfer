//
//  DownloadFileView.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 26/03/2025.
//

import SwiftUI
import QuickLook

struct DownloadFileView: View {
    @StateObject private var viewModel = DownloadViewModel()
    @State private var urlString: String = ""

    var body: some View {
        VStack {
            TextField("Enter file URL...", text: $urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Download") {
                viewModel.startDownload(from: urlString)
            }
            .buttonStyle(.borderedProminent)

            if viewModel.downloadProgress > 0 && viewModel.downloadProgress < 1 {
                ProgressView(value: viewModel.downloadProgress)
                    .padding()
            }

            if let filePath = viewModel.downloadedFilePath {
                Text("Downloaded to: \(filePath.lastPathComponent)")

                Button("Open File Location") {
                    UIApplication.shared.open(filePath)
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
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .padding()
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

@MainActor
class DownloadViewModel: ObservableObject {
    @Published var downloadProgress: Double = 0.0
    @Published var downloadedFilePath: URL?
    @Published var errorMessage: String?
    @Published var isPreviewPresented: Bool = false

    func startDownload(from urlString: String) {
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return
        }

        let delegate = DownloadService(progressHandler: { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress = progress
            }
        })

        let session = URLSession(
            configuration: .background(withIdentifier: UUID().uuidString),
            delegate: delegate,
            delegateQueue: nil
        )

        Task {
            do {
                let filePath = try await delegate.startDownload(using: session, from: url)
                self.downloadedFilePath = filePath
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
