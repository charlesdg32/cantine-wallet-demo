# La Cantine — prototype portefeuille cashless

PWA de démonstration pour une association : portefeuille adhérent, QR permanent révocable, encaissement, demandes de recharge, catalogue, rôles et historique. **Le mode de démonstration est activé par défaut** : les données sont fictives et enregistrées dans le stockage local du navigateur. Il ne traite aucun paiement et n’est pas destiné à une mise en production en l’état.

## Lancer le prototype

Prérequis : Node.js 20 ou plus récent.

```bash
npm install
npm run dev
```

Ouvrez l’URL locale indiquée par Vite. Le sélecteur « Mode de démonstration » simule les profils adhérent, caisse, trésorerie et administration. Les opérations sont conservées dans le navigateur ; « Réinitialiser les données du site » rétablit les exemples. Le scan caméra fonctionne seulement dans un contexte sécurisé (HTTPS ou localhost) et un navigateur compatible. La recherche par nom/code reste disponible.

## Fonctionnalités montrées

- Solde et QR adhérent permanent ; QR révocable depuis le profil.
- Caisse : recherche ou scan d’un QR, articles, quantités, total et refus si le solde démo est insuffisant.
- Recharges : envoi d’un montant et nom de justificatif ; le crédit ne s’applique qu’après approbation simulée.
- Administration : invitation fictive, rôles, activation du catalogue et ajout d’articles.
- En mode connecté, l’onglet Administration → Adhérents affiche les profils de test créés dans Supabase Auth (nom, e-mail, statut et rôle). Les mots de passe ne sont jamais accessibles depuis cette liste.
- L’admin peut modifier le statut d’adhérent; la mise à jour est réservée aux admins et inscrite au journal d’audit. Un membre actif peut utiliser son portefeuille; seul le rôle distinct « caisse » peut encaisser.
- Statut d’adhérent séparé du rôle : « membre actif » permet de payer à la caisse ; le rôle « caisse » autorise l’encaissement.
- Journal qui précise l’adhérent concerné, le demandeur de recharge, le trésorier approbateur et le caissier.
- Vue trésorerie avec recettes, dépenses et résultat net mensuels illustratifs.

Le mode démo n’est pas une simulation de sécurité : les rôles se changent dans l’interface et le stockage peut être modifié par l’utilisateur. N’y mettez ni données personnelles réelles, ni reçus, ni argent réel.

## Connecter Supabase (travail à faire avant toute mise en service)

1. Créez un projet Supabase de test et gardez les clés et reçus entièrement fictifs.
2. Exécutez [`supabase/schema.sql`](supabase/schema.sql) dans le SQL Editor. Faites relire les politiques RLS et fonctions par un développeur avant tout déploiement.
   Pour un projet Supabase déjà créé avec le schéma précédent, exécutez uniquement [`supabase/update_membership_status.sql`](supabase/update_membership_status.sql) afin d’ajouter la modification de statut réservée aux admins et son entrée d’audit.
3. Dans Supabase Auth, créez les comptes de test (Add user) et définissez leurs mots de passe. L’application ne propose pas d’inscription publique. Le schéma crée automatiquement un profil adhérent simple et un portefeuille vide pour chaque compte créé après l’installation du trigger.
4. Pour transformer votre propre compte en premier administrateur, utilisez le SQL Editor avec votre adresse exacte : `update public.profiles set role = 'admin' where email = 'VOTRE_EMAIL';`. Faites cette opération uniquement dans votre projet privé et avec votre adresse. Le rôle ne peut pas être modifié par l’écran de connexion.
5. Dans Cloudflare Workers & Pages → votre Worker → Settings → Variables and Secrets (ou Build variables selon l’écran), ajoutez `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`, puis redéployez. Ce sont les seules valeurs publiques nécessaires au navigateur. Ne placez jamais la clé `service_role` dans le navigateur ni dans une variable `VITE_`.
6. En local, copiez `.env.example` vers `.env.local`, renseignez ces mêmes deux variables, puis relancez `npm run dev`. Sans les variables, l’app affiche un écran verrouillé avec les étapes de configuration. Avec elles, Supabase vérifie l’e-mail et le mot de passe, puis l’app contrôle que le profil associé est actif avant d’ouvrir l’interface.
7. **La connexion Supabase est réelle, mais les écrans du portefeuille utilisent encore les données fictives du navigateur.** Le rôle vérifié masque le sélecteur de rôle démo, mais les écritures et soldes affichés ne sont pas encore ceux du compte Supabase. Ne mettez pas cette version en service pour les opérations réelles.
8. Avant usage, remplacer `src/store.js` par les lectures/écritures du backend. Implémenter des Edge Functions protégées pour inviter un adhérent, attribuer les rôles, créer/renouveler/révoquer le secret QR et produire un upload signé de justificatif; restreindre les reçus dans un bucket privé.
9. L’API prévue appelle `cashier_debit(member_id, items)` avec uniquement les ID de produits et quantités. La fonction verrouille le portefeuille, recalcule les prix depuis la base, contrôle le solde et écrit débit, lignes et audit dans une seule transaction SQL. Ne jamais envoyer un total client faisant autorité.
10. La trésorerie appelle `review_topup(request_id, approve, note)`. La demande est verrouillée et le portefeuille crédité au plus une fois, dans la transaction de la fonction.
11. Tester les rôles et les accès avec des comptes séparés (adhérent, caisse, trésorier, admin), les erreurs concurrentes et les tentatives de modification directe, sur un projet de préproduction.

Le SQL initialise les profils, portefeuilles, produits, demandes, transactions, détails de vente et journal d’audit. Les soldes et écritures ne sont pas modifiables directement par les clients. Les secrets QR doivent être générés avec une source aléatoire cryptographique, conservés sous forme de hash en base et transmis au membre seulement selon un parcours sûr. Un scan doit résoudre le secret côté serveur et vérifier l’adhérent actif. Le QR d’exemple du front est un simple code démo et ne doit pas être réutilisé en production.

## Construire et héberger

```bash
npm run build
```

Le dossier `dist/` peut être hébergé sur une offre statique gratuite (par exemple Cloudflare Pages, Netlify ou Vercel). Configurez le répertoire de sortie `dist` et les variables publiques Supabase uniquement après revue du backend. Toute offre gratuite peut changer ses limites et conditions. Ajoutez une règle de réécriture vers `index.html` si l’hébergeur la demande. Le service worker et le cache hors ligne ne sont pas activés dans ce prototype ; ne mettez pas en cache les appels d’authentification, soldes ou reçus.

## Sécurité et revue avant usage réel

- La valeur est un crédit interne tenu par l’association, pas un compte bancaire ni un moyen de paiement Wero. Le nom Wero ne désigne pas une intégration Wero.
- Clarifier avec l’association et ses conseils les obligations applicables (comptabilité, remboursements, conservation, protection des données et responsabilités).
- Revue indépendante du SQL/RLS, tests d’autorisation, sauvegardes et plan de restauration, limitation de débit et supervision des Edge Functions.
- Vérifier l’identité des caissiers et trésoriers, procédure de retrait des rôles, journalisation protégée contre les modifications, politique de conservation et accès aux reçus.
- Prévoir une procédure d’annulation/correction traçable ; ne pas effacer une vente financièrement pertinente.
- Le prototype n’a pas été connecté à Supabase ni audité. Il sert à valider le parcours et l’ergonomie, pas à déployer des fonds réels.
