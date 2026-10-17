//
//  AppTheme.swift
//  Gohan
//
//  Repris de DesignSystem/AppTheme.swift dans ObjectifsFit (Genki), avec la palette
//  remplacée par Matcha. Mêmes rayons/tailles déjà validés, pour ne pas repartir de zéro.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Design system "Matcha" — fond crème neutre, cartes blanches, accent vert (repris du logo).
enum AppTheme {
    static let background = Color(hex: "F7F8F3")
    static let surface = Color.white
    static let border = Color(hex: "E3E6DC")
    static let accent = Color(hex: "639922")
    static let accentDark = Color(hex: "173404")
    static let textPrimary = Color(hex: "2C2C2A")
    static let textSecondary = Color(hex: "6B6D63")

    static let cardRadius: CGFloat = 14
    static let cardPadding: CGFloat = 14
    static let buttonRadius: CGFloat = 11

    enum Font {
        static let statValue = SwiftUI.Font.system(size: 26, weight: .semibold, design: .rounded)
        static let statLabel = SwiftUI.Font.system(size: 12, weight: .medium)
        static let cardTitle = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let sectionHeader = SwiftUI.Font.system(size: 12, weight: .semibold)
    }
}

/// Style de carte réutilisable : fond blanc, bordure fine, coin arrondi — remplace le style
/// "réglages iOS" par défaut des List/Form.
struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

/// Styles de bouton partagés — un seul rayon de coin (`AppTheme.buttonRadius`) pour tous les
/// boutons "boîte" de l'app.
extension View {
    /// Action principale pleine largeur d'un écran ou d'une carte (fond vert).
    func primaryButtonStyle() -> some View {
        self
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
    }

    /// Action secondaire pleine largeur (contour gris, fond blanc).
    func secondaryButtonStyle() -> some View {
        self
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(AppTheme.textPrimary)
            .background(AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonRadius).stroke(AppTheme.border, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
    }

    /// Action rapide compacte intégrée dans une ligne/carte existante (pas pleine largeur).
    func compactAccentButtonStyle(fontSize: CGFloat = 13, verticalPadding: CGFloat = 9, horizontalPadding: CGFloat = 16) -> some View {
        self
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
    }
}

/// Enchaîne des vues (typiquement des badges) avec retour à la ligne automatique — pour les
/// listes de tags de longueur variable où un `HStack` déborderait.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + spacing
                currentRowWidth = 0
                currentRowHeight = 0
            }
            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += currentRowHeight + spacing
                currentRowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(AppTheme.Font.sectionHeader)
            .tracking(0.6)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 4)
    }
}

/// Applique les couleurs de fond de liste/nav/tab bar du thème sur toute l'app.
enum AppAppearance {
    static func apply() {
        let bg = UIColor(AppTheme.background)
        let surface = UIColor(AppTheme.surface)
        let accent = UIColor(AppTheme.accent)

        UITableView.appearance().backgroundColor = bg
        UICollectionView.appearance().backgroundColor = bg
        UITableView.appearance().separatorColor = UIColor(AppTheme.border)
        UITableViewCell.appearance().backgroundColor = surface

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = bg
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.textPrimary)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppTheme.textPrimary)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accent

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = surface
        tabAppearance.shadowColor = UIColor(AppTheme.border)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = accent
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppTheme.textSecondary)
    }
}
