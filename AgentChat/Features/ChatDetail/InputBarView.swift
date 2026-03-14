import SwiftUI
import PhotosUI

struct InputBarView: View {
    @Binding var text: String
    let onSend: () -> Void
    let onAttachmentPicked: (Data, UIImage) -> Void
    let onSendWithAttachment: () -> Void
    let pendingAttachment: PendingAttachment?
    let onClearAttachment: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingImageSourceMenu = false
    @State private var showingCamera = false

    private let minHeight: CGFloat = 36
    private let maxHeight: CGFloat = 120

    var body: some View {
        VStack(spacing: 0) {
            if let attachment = pendingAttachment {
                pendingAttachmentPreview(attachment)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Attachment button
                Button {
                    showingImageSourceMenu = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                .confirmationDialog("Add Photo", isPresented: $showingImageSourceMenu) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Text("Photo Library")
                    }
                    Button("Camera") {
                        showingCamera = true
                    }
                    Button("Cancel", role: .cancel) {}
                }

                // Text input
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text("Message")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $text)
                        .frame(minHeight: minHeight, maxHeight: maxHeight)
                        .fixedSize(horizontal: false, vertical: true)
                        .scrollContentBackground(.hidden)
                        .accessibilityIdentifier("messageInput")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 18))

                // Send button
                Button(action: pendingAttachment != nil ? onSendWithAttachment : onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(isSendDisabled ? Color(.systemGray4) : .blue)
                }
                .disabled(isSendDisabled)
                .accessibilityIdentifier("sendButton")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onAttachmentPicked(data, image)
                }
                selectedPhotoItem = nil
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPickerView { data, image in
                onAttachmentPicked(data, image)
            }
        }
    }

    private var isSendDisabled: Bool {
        if pendingAttachment != nil { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func pendingAttachmentPreview(_ attachment: PendingAttachment) -> some View {
        HStack(spacing: 8) {
            Image(uiImage: attachment.previewImage)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Image ready to send")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onClearAttachment()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Camera Picker

private struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (Data, UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data, UIImage) -> Void

        init(onCapture: @escaping (Data, UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.8) else { return }
            onCapture(data, image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
