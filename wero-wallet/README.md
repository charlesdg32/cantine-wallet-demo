# La Cantine — version 8 connectée

Cette mise à jour rétablit l’espace connecté autour des comptes Supabase : QR personnel vérifié côté serveur, accès aux onglets selon le rôle, ventes enregistrées par Supabase, recharges avec justificatif privé, produits et historique. Les anciens fichiers restent dans le paquet v7 ; utilisez ce dossier v8 pour la mise à jour.

## Avant de remplacer les fichiers du site

1. Dans Supabase, ouvrez **SQL Editor → New query**.
2. Copiez le contenu de `supabase/qr_roles_live_migration.sql`, puis cliquez sur **Run**. La migration ajoute les fonctions QR sécurisées, les droits de lecture nécessaires à la caisse et le bucket privé des reçus.
3. Attendez le message **Success**. En cas d’erreur, arrêtez-vous et transmettez le texte de l’erreur sans publier de clé ou de mot de passe.
4. Dans GitHub, entrez dans `wero-wallet` et remplacez son contenu par celui de ce dossier v8. Conservez les variables Cloudflare existantes `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`.
5. Validez le changement GitHub et attendez le déploiement vert sur Cloudflare Pages.
6. Déconnectez-vous puis reconnectez-vous. La connexion crée un QR neuf ; tout ancien QR est invalidé à chaque nouvelle connexion ou renouvellement.

## Rôles

- **Adhérent** : compte, solde, historique et QR personnel.
- **Membre actif** : accès adhérent et caisse.
- **Trésorier** : accès membre actif, demandes de recharge et tableau de suivi.
- **Administrateur** : accès complet, gestion des rôles, produits et journal d’audit.

Attribuez les rôles depuis **Administration → Adhérents**. Un compte doit aussi être approuvé pour se connecter. Le scanner nécessite une page HTTPS et l’autorisation d’utiliser la caméra. Si le navigateur ne prend pas en charge son scanner QR, la recherche par nom reste disponible.

## Sécurité et limites

Le token QR clair n’est jamais stocké dans la base : Supabase ne garde que son empreinte. Une connexion ou un renouvellement crée un QR différent et invalide l’ancien. Les débits sont validés dans la fonction SQL `cashier_debit`; les soldes ne sont pas modifiés directement depuis le navigateur.

Les reçus sont déposés dans un bucket Supabase privé avec accès limité. Le tableau de trésorerie distingue les recharges approuvées et les ventes ; il ne prétend pas calculer le bénéfice comptable réel. Cette version reste un essai interne : avant tout usage financier réel, faites examiner les règles RLS, la procédure de rapprochement et la sauvegarde des données.

N’ajoutez jamais une clé `service_role` dans Cloudflare Pages ou dans le code du navigateur. Les identifiants Brevo restent dans la configuration SMTP Supabase, pas dans GitHub.
