//
//  AppTheme.swift
//  Gohan
//
//  Repris de DesignSystem/AppTheme.swift dans ObjectifsFit (Genki), avec la palette
//  remplacée par Matcha. Mêmes rayons/tailles déjà validés, pour ne pas repartir de zéro.
//

import SwiftUI

extension UIColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = CGFloat((value & 0xFF0000) >> 16) / 255
        let g = CGFloat((value & 0x00FF00) >> 8) / 255
        let b = CGFloat(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// Couleur qui bascule entre une variante claire et une variante sombre selon l'apparence
    /// système — contrairement à `Color(hex:)` qui reste fixe dans les deux modes.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// Design system "Matcha" — fond crème neutre, cartes blanches, accent vert (repris du logo).
/// L'accent reste identique en clair/sombre (identité de marque) ; seuls fond/carte/bordure/
/// textes et `accentOnTint` ont une variante sombre.
enum AppTheme {
    static let background = Color(light: "F7F8F3", dark: "15170F")
    static let surface = Color(light: "FFFFFF", dark: "20231A")
    static let border = Color(light: "E3E6DC", dark: "363A2C")
    static let accent = Color(hex: "639922")
    /// Fixe dans les deux modes : fond du toast flottant, pas suivi l'ambiance de l'écran.
    static let accentDark = Color(hex: "173404")
    /// Texte des tags/chips sur fond teinté (`accent.opacity(0.12)`) — doit s'inverser pour
    /// rester lisible : foncé sur fond pâle en clair, clair sur fond teinté sombre en sombre.
    static let accentOnTint = Color(light: "173404", dark: "A8D97A")
    /// Icône calories (flamme) sur les cartes recette — seul autre accent que le vert, pour
    /// casser le gris uniforme sans multiplier les couleurs. Fixe dans les deux modes.
    static let calorieOrange = Color(hex: "E8742C")
    static let textPrimary = Color(light: "2C2C2A", dark: "F2F3EC")
    static let textSecondary = Color(light: "6B6D63", dark: "9BA08C")

    /// Signale un champ à vérifier après un import IA (donnée manquante ou incertaine) — jamais
    /// une erreur bloquante, juste une invitation à relire avant d'enregistrer.
    static let warningBackground = Color(light: "FBEFD9", dark: "3A2E12")
    static let warningBorder = Color(light: "E8B85A", dark: "8A6A26")
    static let warningText = Color(light: "7A5B12", dark: "E8C98A")

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
