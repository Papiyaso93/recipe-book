# Gohan 🍚

App iOS personnelle de centralisation de recettes de cuisine — successeure de [Gustave](.), une première version faite avec Glide (no-code), limitée en UI/UX et en automatisation.

Le nom fait écho à [Genki](.), une autre app perso (sport/fitness) de l'auteur — clin d'œil Dragon Ball (Genki ↔ Genkidama, Gohan ↔ le fils de Goku), tout en restant un vrai mot japonais signifiant "repas/riz".

## Vision

- Usage **100% personnel**, mono-utilisateur. Pas de système social/amis (contrairement à Gustave) — mais possibilité de partager une recette ponctuellement à quelqu'un qui n'a pas l'app.
- Priorité à une **UX soignée et fluide**, ce que Glide ne permettait pas.
- La vraie valeur ajoutée par rapport à Gustave : **automatiser la création de recettes** via photo (livre de cuisine) et import depuis les réseaux sociaux, plutôt que de tout saisir à la main.

## Plateforme & stack technique

- **iOS natif**, SwiftUI + SwiftData (cohérent avec l'autre app perso [ObjectifsFit](.))
- **Synchronisation multi-appareils** via iCloud (SwiftData + CloudKit) — gratuit, pas de backend serveur custom à maintenir
- **Fonctionnement hors-ligne** pour toute consultation/cuisine d'une recette déjà enregistrée. Seuls les imports par IA (photo, réseaux sociaux) nécessitent une connexion.
- **Distribution** : build Xcode → installation directe sur iPhone perso pour commencer (gratuit). Passage à un compte Apple Developer (99$/an) envisageable plus tard si besoin d'App Store/TestFlight — pas une priorité V1.

## Fonctionnalités

### Recettes — CRUD
- Création / modification / suppression
- Champs : nom, photo(s), nombre de portions, temps de préparation, temps de cuisson, étapes de préparation, matériel nécessaire, ingrédients (avec quantité + unité), tags/catégories, lien vers la recette d'origine (optionnel), notes personnelles horodatées (ex: "revoir la quantité de sel la prochaine fois")
- Étapes avec vidéo courte optionnelle (type boomerang, quelques secondes) — **post-V1**, stockage en pièce jointe CloudKit, pas de compression custom nécessaire au départ

### Ingrédients & nutrition
- Base de données d'ingrédients réutilisée/étendue depuis Gustave : nom, code CIQUAL (base nutritionnelle officielle française) quand disponible, valeurs nutritionnelles pour 100g (calories, protéines, glucides, lipides, fibres), groupe d'ingrédient (fruits frais, légumes, produits laitiers...)
- **Table de conversion unité → grammes** par ingrédient, pour permettre une saisie naturelle ("1 cuillère à café", "2 unités"...) tout en calculant les valeurs nutritionnelles en interne en grammes. L'unité d'origine reste affichée à l'utilisateur.
- **Valeurs nutritionnelles calculées automatiquement** par recette et par portion (calories/protéines/glucides/lipides), à partir des ingrédients et de leurs quantités

### Favoris
- Marquer/démarquer une recette comme favorite, vue dédiée listant les favoris

### Liste de courses
- Ajouter/retirer un ingrédient d'une recette à la liste de courses
- **Cumul automatique** par ingrédient + unité quand plusieurs recettes utilisent le même ingrédient (ex: 2 recettes à 100g de farine chacune → une ligne "200g de farine"), avec possibilité de déplier pour voir la provenance par recette
- **Regroupement par catégorie d'ingrédient** (fruits, légumes, produits laitiers...) pour correspondre au parcours en magasin
- Cases à cocher pendant les courses

### Import de recette par photo (livre de cuisine)
- Prise d'une ou plusieurs photos de page(s) de livre de recettes
- Extraction automatique par IA (OCR + structuration) en recette complète (nom, ingrédients, quantités, étapes...)
- **Écran de relecture/édition obligatoire** avant sauvegarde définitive, l'IA pouvant se tromper

### Import de recette depuis les réseaux sociaux
- **Scope V1** : coller un lien Instagram ou Pinterest → l'IA lit la légende/texte du post + l'image associée pour extraire la recette structurée
- Écran de relecture/édition avant sauvegarde, comme pour l'import photo
- **Hors scope V1** : transcription audio des reels/vidéos (plus complexe et coûteux, à évaluer plus tard selon pertinence réelle)

### Partage de recette
- Génération d'une **fiche visuelle** (image ou PDF) de la recette, partagée via le partage natif iOS (Messages, Mail, WhatsApp...)
- Le destinataire n'a pas besoin d'avoir l'app pour consulter la recette

### Mode cuisine
- Vue plein écran dédiée pendant la préparation : étapes affichées une par une en grand, navigation simple, écran qui ne s'éteint pas automatiquement — pensé pour cuisiner les mains potentiellement sales/occupées

### Recherche & filtres
- Recherche texte par nom de recette
- Filtres par **tags multi-facettes** (ex : type de plat, régime alimentaire, caractéristiques comme "rapide" ou "sans cuisson") plutôt qu'une liste plate unique comme dans Gustave — taxonomie précise à définir lors de l'implémentation de cet écran

## Hors scope (abandonné par rapport à Gustave)

- Système social : amis, recettes des amis, demandes d'ami, recherche de membres
- Commentaires multi-utilisateurs — remplacés par les notes personnelles horodatées sur chaque recette

## Migration des données

Les ~20 recettes existantes de Gustave (export CSV : recettes, ingrédients, valeurs nutritionnelles, catégories, matériel...) seront importées dans Gohan au lancement, pour ne pas repartir de zéro.

## Points à préciser pendant l'implémentation (non bloquants pour démarrer)

- Taxonomie précise des tags/filtres (type de plat / régime / caractéristiques)
- Choix technique du modèle IA pour l'OCR + extraction structurée des recettes (photo et réseaux sociaux), et gestion du coût par appel
- Faisabilité technique de la récupération de contenu Instagram/Pinterest (pas d'API publique officielle dédiée, à valider techniquement)
- Implémentation des vidéos par étape (stockage CloudKit, limites de taille/durée) — prévue après le cœur de l'app
