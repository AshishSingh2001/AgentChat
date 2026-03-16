import SwiftUI

struct MessageListView: View {
    @Bindable var viewModel: ChatDetailViewModel
    let fileStorageService: any FileStorageServiceProtocol

    @State private var scrollPosition = ScrollPosition(idType: String.self)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.messages.isLoadingOlder {
                    ProgressView()
                        .frame(height: 40)
                        .rotationEffect(.degrees(180))
                }

                ForEach(viewModel.messages.messages.reversed()) { message in
                    MessageBubbleView(
                        message: message,
                        fileStorageService: fileStorageService,
                        onImageTap: { file in
                            let path = file.path
                            if let url = path.hasPrefix("http")
                                ? URL(string: path)
                                : fileStorageService.absoluteURL(for: path) {
                                viewModel.openImageViewer(url: url)
                            }
                        }
                    )
                    .rotationEffect(.degrees(180))
                    .id(message.id)
                }

                if viewModel.messages.messages.isEmpty && !viewModel.messages.isLoadingOlder {
                    ContentUnavailableView(
                        "No Messages",
                        systemImage: "bubble.left",
                        description: Text("Send a message to begin")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                    .rotationEffect(.degrees(180))
                }
            }
            .padding(.vertical, 8)
        }
        .rotationEffect(.degrees(180))
        .scrollPosition($scrollPosition)

        // In rotationEffect(180°) layout: offset 0 = visual bottom (newest messages)
        // Distance from visual bottom = contentOffset.y directly
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, offsetFromBottom in
            viewModel.scroll.updateScrollOffset(offsetFromBottom)
        }

        // Pagination: scrolled toward older messages (visually up) = contentOffset.y near max
        .onScrollGeometryChange(for: Bool.self) { geo in
            let maxOffset = geo.contentSize.height - geo.visibleRect.height
            return maxOffset > 0 && geo.contentOffset.y > maxOffset * 0.75
        } action: { _, nearOldest in
            if nearOldest { viewModel.loadOlderMessages() }
        }

        // Scroll to newest when triggered (newest = first in reversed list = visual bottom)
        .onChange(of: viewModel.scroll.shouldScrollToBottom) { _, newValue in
            guard newValue, let newestId = viewModel.messages.messages.last?.id else { return }
            let delay = viewModel.scroll.scrollDelay
            viewModel.scroll.shouldScrollToBottom = false
            Task { @MainActor in
                if delay > .zero { try? await Task.sleep(for: delay) }
                withAnimation { scrollPosition.scrollTo(id: newestId, anchor: .bottom) }
            }
        }

        .overlay(alignment: .bottom) {
            if viewModel.scroll.showNewMessageToast {
                Button {
                    if let newestId = viewModel.messages.messages.last?.id {
                        withAnimation { scrollPosition.scrollTo(id: newestId, anchor: .bottom) }
                    }
                    viewModel.scroll.dismissToast()
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
                .accessibilityIdentifier("newMessageToastButton")
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.scroll.showNewMessageToast)
    }
}
