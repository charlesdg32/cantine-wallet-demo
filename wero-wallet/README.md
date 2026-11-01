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
- Statut d’adhérent séparé du rôle : « membre actif » permet de payer à la caisse ; le rôle « caisse » autorise l’encaissement.
- Journal qui précise l’adhérent concerné, le demandeur de recharge, le trésorier approbateur et le caissier.
- Vue trésorerie avec recettes, dépenses et résultat net mensuels illustratifs.

Le mode démo n’est pas une simulation de sécurité : les rôles se changent dans l’interface et le stockage peut être modifié par l’utilisateur. N’y mettez ni données personnelles réelles, ni reçus, ni argent réel.

## Connecter Supabase (travail à faire avant toute mise en service)

1. Créez un projet Supabase de test et gardez les clés et reçus entièrement fictifs.
2. Exécutez [`supabase/schema.sql`](supabase/schema.sql) dans le SQL Editor. Faites relire les politiques RLS et fonctions par un développeur avant tout déploiement.
3. Copiez `.env.example` en `.env.local`, puis renseignez l’URL du projet et la clé `anon` publique. Ne placez jamais la clé `service_role` dans le navigateur ou dans une variable `VITE_`.
4. Ajouter un client Supabase (Auth + appels RPC) et remplacer `src/store.js`. Le code UI actuel utilise expressément `demoStore()` et ne bascule pas vers un backend par la seule présence des variables.
5. Implémenter des Edge Functions protégées pour inviter un adhérent avec Supabase Auth, attribuer le rôle depuis une liste autorisée, créer/renouveler/révoquer le secret QR, produire un upload signé de justificatif, et notifier l’adhérent. Restreindre les reçus dans un bucket privé.
6. Appeler `cashier_debit(member_id, items)` avec uniquement les ID de produits et quantités. La fonction verrouille le portefeuille, recalcule les prix depuis la base, contrôle le solde et écrit débit, lignes et audit dans une seule transaction SQL. Ne jamais envoyer un total client faisant autorité.
7. La trésorerie appelle `review_topup(request_id, approve, note)`. La demande est verrouillée et le portefeuille crédité au plus une fois, dans la transaction de la fonction.
8. Tester les rôles et les accès avec des comptes séparés (adhérent, caisse, trésorier, admin), les erreurs concurrentes et les tentatives de modification directe, sur un projet de préproduction.

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
