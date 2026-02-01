import SwiftUI

// MARK: - Glassmorphism View Modifiers
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 20
    var opacity: Double = 0.2
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            )
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            )
    }
}

struct GlassButton: ViewModifier {
    var isEnabled: Bool = true
    
    private var gradientColors: [Color] {
        isEnabled ? [
            Color.blue.opacity(0.5),
            Color.purple.opacity(0.4),
            Color.pink.opacity(0.2)
        ] : [
            Color.gray.opacity(0.25),
            Color.gray.opacity(0.15)
        ]
    }
    
    @ViewBuilder
    private var backgroundShape: some View {
        if isEnabled {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)
                .shadow(color: Color.purple.opacity(0.2), radius: 8, x: 0, y: 3)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                backgroundShape
            }
    }
}

struct GlassTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
            }
    }
}

// MARK: - View Extensions
extension View {
    func glassBackground(cornerRadius: CGFloat = 20, opacity: Double = 0.2) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, opacity: opacity))
    }
    
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
    
    func glassButton(isEnabled: Bool = true) -> some View {
        modifier(GlassButton(isEnabled: isEnabled))
    }
    
    func glassTextField() -> some View {
        modifier(GlassTextField())
    }
}

// MARK: - Glassmorphism Container View
struct GlassContainer<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    
    init(cornerRadius: CGFloat = 20, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Enhanced gradient overlay for iOS 17+
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        // Enhanced border with better gradient
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: 12)
                    .shadow(color: Color.blue.opacity(0.1), radius: 15, x: 0, y: 6)
            }
    }
}
