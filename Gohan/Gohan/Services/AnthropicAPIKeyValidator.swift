//
//  AnthropicAPIKeyValidator.swift
//  Gohan
//

import Foundation

enum APIKeyValidationError: LocalizedError {
    case invalidKey
    case insufficientCredits
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Clé invalide — vérifie qu'elle est correcte."
        case .insufficientCredits: return "Clé valide, mais le compte Anthropic associé n'a plus de crédit."
        case .networkError: return "Impossible de vérifier la clé, vérifie ta connexion."
        }
    }
}

enum AnthropicAPIKeyValidator {
    /// Appel minimal (1 jeton de sortie) juste pour confirmer que la clé s'authentifie — pas
    /// pour obtenir une vraie réponse. Un 401/403 signifie une clé invalide. Un 400 dont le
    /// message mentionne le crédit signifie une clé valide mais un compte sans crédit (sinon
    /// cette clé passerait pour "connectée" alors qu'elle ne pourra jamais importer de recette).
    /// Tout le reste (200, 429 limite de débit, 529 surcharge) prouve que la clé a bien passé la
    /// couche d'authentification d'Anthropic.
    static func validate(_ apiKey: String) async -> Result<Void, APIKeyValidationError> {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return .failure(.networkError)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return .failure(.networkError) }
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return .failure(.invalidKey)
            }
            if httpResponse.statusCode == 400, isInsufficientCreditsBody(data) {
                return .failure(.insufficientCredits)
            }
            return .success(())
        } catch {
            return .failure(.networkError)
        }
    }

    private static func isInsufficientCreditsBody(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return false
        }
        return message.localizedCaseInsensitiveContains("credit balance")
    }
}
