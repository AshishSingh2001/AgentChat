import SwiftUI

struct MessageListView: View {
    @Bindable var viewModel: ChatDetailViewModel
    let fileStorageService: FileStorageService

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.messages.isEmpty {
                    ContentUnavailableView(
                        "No Messages",
                        systemImage: "bubble.left",
                        description: Text("Send a message to begin")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            fileStorageService: fileStorageService,
                            onImageTap: { file in viewModel.openImageViewer(for: file) }
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentSize.height - geo.visibleRect.maxY
            } action: { _, offsetFromBottom in
                viewModel.updateScrollOffset(offsetFromBottom)
            }
            .onChange(of: viewModel.shouldScrollToBottom) { _, newValue in
                if newValue, let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                    viewModel.shouldScrollToBottom = false
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.showNewMessageToast {
                    Button {
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                        }
                        viewModel.dismissToast()
                    } label: {
                        Label("New message", systemImage: "arrow.down")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                    }
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.showNewMessageToast)
        }
    }
}
