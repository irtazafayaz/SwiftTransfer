//
//  DownloadListView.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 14/08/2025.
//

import SwiftUI
import QuickLook

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
                        }

                        HStack(alignment: .center) {
                            StatusPill(status: item.status)
                            Spacer(minLength: 12)

                            if item.status == "Downloading" {
                                IconButton(
                                    "xmark.circle",
                                    variant: .plain,
                                    size: .md,
                                    role: .destructive,
                                    accessibilityLabel: "Cancel download"
                                ) {
                                    viewModel.cancelDownload(id: item.id)
                                }
                            } else if item.localFileURL != nil {
                                IconButton(
                                    "eye",
                                    variant: .filled,
                                    size: .sm,
                                    accessibilityLabel: "Preview file"
                                ) {
                                    viewModel.preview(id: item.id)
                                }
                                IconButton(
                                    "square.and.arrow.up",
                                    variant: .filled,
                                    size: .sm,
                                    accessibilityLabel: "Save or share"
                                ) {
                                    viewModel.saveOrShare(id: item.id)
                                }
                            }
                        }
                        .animation(.easeInOut, value: item.status)
                        .padding(.top, 4)


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
        .quickLookPreview($viewModel.previewURL)
        .sheet(item: $viewModel.shareItem, onDismiss: {
            viewModel.shareItem = nil
        }) { item in
            ActivityView(items: [item.url]).ignoresSafeArea()
        }

    }
}

struct StatusPill: View {
    let status: String

    var body: some View {
        let s = style(for: status)

        Label(s.title, systemImage: s.icon)
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(s.fg)
            .background(s.bg, in: Capsule())
    }

    private func style(for status: String) -> (title: String, icon: String, bg: Color, fg: Color) {
        let key = status
            .split(separator: ":")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? status.lowercased()

        switch key {
        case "downloading":
            return ("Downloading", "arrow.down.circle", Color.yellow.opacity(0.15), .yellow)
        case "completed":
            return ("Completed", "checkmark.circle.fill", Color.green.opacity(0.15), .green)
        case "failed":
            return ("Failed", "exclamationmark.triangle.fill", Color.red.opacity(0.15), .red)
        case "canceled":
            return ("Canceled", "xmark.circle.fill", Color.gray.opacity(0.2), .gray)
        default:
            return ("Ready", "doc.fill", Color.secondary.opacity(0.12), .secondary)
        }
    }
}


#Preview {
    DownloadListView()
}
