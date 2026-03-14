import SwiftUI
import SDWebImageSwiftUI

struct ImageViewerItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ImageViewerView: View {
    let item: ImageViewerItem
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = 1.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            GeometryReader { geo in
                WebImage(url: item.url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    ProgressView()
                        .tint(.white)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(scale)
                .offset(x: panOffset.width + (scale <= 1.0 ? dragOffset.width : 0),
                        y: panOffset.height + (scale <= 1.0 ? dragOffset.height : 0))
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = max(1.0, lastScale * value.magnification)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale <= 1.0 {
                                withAnimation(.spring) {
                                    scale = 1.0
                                    lastScale = 1.0
                                    panOffset = .zero
                                    lastPanOffset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                panOffset = CGSize(
                                    width: lastPanOffset.width + value.translation.width,
                                    height: lastPanOffset.height + value.translation.height
                                )
                            } else {
                                dragOffset = value.translation
                                let progress = min(abs(value.translation.height) / 300, 1.0)
                                backgroundOpacity = 1.0 - progress * 0.5
                            }
                        }
                        .onEnded { value in
                            if scale > 1.0 {
                                lastPanOffset = panOffset
                            } else {
                                if abs(value.translation.height) > 100 {
                                    onDismiss()
                                } else {
                                    withAnimation(.spring) {
                                        dragOffset = .zero
                                        backgroundOpacity = 1.0
                                    }
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring) {
                        if scale > 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                            panOffset = .zero
                            lastPanOffset = .zero
                        } else {
                            scale = 2.0
                            lastScale = 2.0
                        }
                    }
                }
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(.systemGray2).opacity(0.7))
                    .padding(16)
            }
        }
    }
}
