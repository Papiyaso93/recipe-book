//
//  RecipeImportService.swift
//  Gohan
//

import Foundation

enum RecipeImportError: LocalizedError, Equatable {
    case noAPIKey
    case invalidKey
    case insufficientCredits
    case networkError
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Configure ta clé API Anthropic dans Réglages pour importer une recette par photo."
        case .invalidKey: return "Ta clé API Anthropic est invalide ou a expiré — vérifie-la dans Réglages."
        case .insufficientCredits: return "Ton compte Anthropic associé n'a plus de crédit."
        case .networkError: return "Impossible de contacter l'API — vérifie ta connexion et réessaie."
        case .extractionFailed: return "Impossible de lire cette photo, réessaie avec une photo plus nette."
        }
    }
}

enum RecipeImportService {
    /// Demande un JSON strict plutôt qu'une réponse en langage naturel — sans ça, il faudrait
    /// reparser du texte libre pour en extraire une recette structurée, bien moins fiable.
    ///
    /// Le rapprochement avec la bibliothèque d'ingrédients existants se fait ICI, par l'IA —
    /// pas en local par égalité stricte de chaînes (qui ratait "poulet fermier bio" face à
    /// "Poulet"). Lui donner la liste et lui demander de choisir le plus proche est bien plus
    /// robuste qu'essayer d'étoffer indéfiniment la base pour couvrir toutes les variantes
    /// possibles — voir issue #59.
    private static func extractionPrompt(knownIngredientNames: [String]) -> String {
        let ingredientList = knownIngredientNames.sorted().joined(separator: ", ")
        return """
        Tu extrais le contenu d'une recette de cuisine à partir d'une photo (page de livre, note manuscrite ou capture d'écran). Réponds UNIQUEMENT avec un objet JSON, sans texte ni balises autour, au format exact suivant :

        {
          "name": "string",
          "servings": nombre entier ou null,
          "prepTimeMinutes": nombre entier ou null,
          "cookTimeMinutes": nombre entier ou null,
          "steps": ["string", ...],
          "ingredients": [
            {"name": "string", "matchedName": "string ou null", "quantity": nombre ou null, "unit": "string ou null", "quantityUncertain": booléen}
          ],
          "materials": ["string", ...]
        }

        "name" est le nom de l'ingrédient tel que lu sur la photo (reste précis, ex: "poulet fermier bio Label Rouge"). "matchedName" est le nom le PLUS PROCHE dans cette liste d'ingrédients déjà connus de l'application, en utilisant ton bon sens culinaire (ex: "poulet fermier bio" → "Poulet", "parmesan râpé" → "Parmesan") — mets null seulement si vraiment rien ne correspond raisonnablement. Liste des ingrédients connus : [\(ingredientList)].

        "quantityUncertain" doit être true seulement quand tu n'es pas sûr d'avoir bien lu la quantité (écriture ambiguë, chiffre flou, ou quantité non chiffrée comme "au goût"/"une pincée" — dans ce dernier cas laisse "quantity" à null). Les unités doivent rester simples (ex: "g", "cuillère à soupe", "unité"). "materials" liste le matériel de cuisine notable nécessaire (ex: "four", "robot pâtissier", "moule à tarte", "mixeur") — qu'il soit dans une section dédiée OU seulement mentionné au fil des étapes (ex: "enfourner 20 min" implique "four"). N'inclus jamais d'ustensiles basiques évidents (couteau, planche à découper, bol, cuillère). Si une information n'est pas présente sur la photo, utilise null (ou un tableau vide pour les étapes/ingrédients/matériel) plutôt que d'inventer.
        """
    }

    /// Modèle plus capable que celui utilisé pour la simple validation de clé (voir
    /// `AnthropicAPIKeyValidator`) — la lecture d'une écriture manuscrite ou d'une photo de
    /// mauvaise qualité bénéficie d'un modèle plus précis, et le volume d'imports reste faible
    /// (usage personnel), donc le surcoût est négligeable.
    private static let model = "claude-sonnet-5-5"

    static func importRecipe(from imageData: Data, knownIngredientNames: [String]) async -> Result<ExtractedRecipeDraft, RecipeImportError> {
        guard let apiKey = KeychainStore.load(forKey: SettingsView.anthropicAPIKeyStorageKey), !apiKey.isEmpty else {
            return .failure(.noAPIKey)
        }
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return .failure(.networkError)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            // Une recette avec beaucoup d'ingrédients/étapes détaillées peut dépasser 2048
            // tokens de JSON — une réponse tronquée en plein milieu devient alors indécodable
            // (constaté en test réel sur une recette chargée).
            "max_tokens": 4096,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": imageData.base64EncodedString()]],
                    ["type": "text", "text": extractionPrompt(knownIngredientNames: knownIngredientNames)],
                ],
            ]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .failure(.networkError)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.networkError)
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            return .failure(.invalidKey)
        }
        if httpResponse.statusCode == 400, isInsufficientCreditsBody(data) {
            return .failure(.insufficientCredits)
        }
        guard httpResponse.statusCode == 200 else {
            logFailure("HTTP \(httpResponse.statusCode)", data: data)
            return .failure(.extractionFailed)
        }
        guard var draft = parseDraft(from: data) else {
            logFailure("JSON de la recette indécodable", data: data)
            return .failure(.extractionFailed)
        }
        draft.photoData = imageData
        return .success(draft)
    }

    /// Visible dans la console Xcode (pas dans l'app) — le seul moyen de distinguer les causes
    /// derrière le message générique affiché à l'utilisateur tant qu'on n'a pas plus de recul
    /// sur les échecs réels en usage.
    private static func logFailure(_ reason: String, data: Data) {
        let bodyPreview = String(data: data, encoding: .utf8)?.prefix(2000) ?? "(non-UTF8)"
        print("[RecipeImportService] Échec d'extraction — \(reason)\n\(bodyPreview)")
    }

    private static func isInsufficientCreditsBody(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return false
        }
        return message.localizedCaseInsensitiveContains("credit balance")
    }

    private struct APIResponse: Decodable {
        struct ContentBlock: Decodable { let text: String? }
        let content: [ContentBlock]
    }

    private struct ExtractedJSON: Decodable {
        struct Ingredient: Decodable {
            let name: String
            let matchedName: String?
            let quantity: Double?
            let unit: String?
            let quantityUncertain: Bool?
        }
        let name: String?
        let servings: Int?
        let prepTimeMinutes: Int?
        let cookTimeMinutes: Int?
        let steps: [String]?
        let ingredients: [Ingredient]?
        let materials: [String]?
    }

    private static func parseDraft(from data: Data) -> ExtractedRecipeDraft? {
        // `.first?.text` raterait le texte si un bloc "thinking" (raisonnement) précède le
        // texte dans la réponse — les modèles Sonnet actuels en ajoutent par défaut.
        guard let response = try? JSONDecoder().decode(APIResponse.self, from: data),
              let rawText = response.content.compactMap(\.text).first else {
            return nil
        }
        // Le modèle respecte presque toujours la consigne "JSON seul", mais il lui arrive
        // d'entourer sa réponse de ```json ... ``` malgré la consigne contraire.
        let cleaned = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = cleaned.data(using: .utf8),
              let extracted = try? JSONDecoder().decode(ExtractedJSON.self, from: jsonData),
              let name = extracted.name, !name.isEmpty else {
            return nil
        }

        var draft = ExtractedRecipeDraft()
        draft.name = name
        draft.servings = extracted.servings
        draft.prepTimeMinutes = extracted.prepTimeMinutes
        draft.cookTimeMinutes = extracted.cookTimeMinutes
        draft.steps = extracted.steps ?? []
        draft.ingredientLines = (extracted.ingredients ?? []).map {
            ExtractedRecipeDraft.IngredientLine(
                rawName: $0.name,
                matchedName: $0.matchedName,
                quantity: $0.quantity,
                unitName: $0.unit,
                quantityUncertain: $0.quantityUncertain ?? false
            )
        }
        draft.materialNames = extracted.materials ?? []
        return draft
    }
}
