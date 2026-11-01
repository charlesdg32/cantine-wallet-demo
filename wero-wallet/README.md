# La Cantine — essai interne

Cette version sert à tester les demandes de compte et les rôles avec 2 ou 3 personnes. Les noms et comptes de démonstration ont été retirés. Le formulaire de demande demande le nom et prénom, l’adresse e-mail et un mot de passe. Supabase Auth gère les mots de passe, y compris la récupération par e-mail.

## Parcours d’accès

- Demande d’accès avec nom, e-mail et mot de passe.
- Approbation manuelle d’un compte et attribution d’un des quatre rôles dans Administration → Adhérents.
- Lien « Mot de passe oublié ? » sur l’écran de connexion, puis choix du nouveau mot de passe après ouverture du lien reçu.

## Paramètres Supabase nécessaires

Dans **Authentication → URL Configuration** :

- **Site URL** : `https://cantine-wallet-demo.pages.dev`
- **Redirect URLs** : ajoutez `https://cantine-wallet-demo.pages.dev/` (l’adresse racine exacte, avec `/` final).

La version déployée envoie les e-mails de confirmation et de récupération vers la racine du site Pages. Si vous utilisez une URL de prévisualisation Cloudflare au lieu de l’adresse permanente, ajoutez aussi cette adresse exacte à **Redirect URLs**.

Dans **Authentication → Providers / Sign In** (le nom peut varier), les inscriptions par e-mail doivent être activées. Les liens de récupération sont à usage limité et expirent ; demandez un nouveau lien si l’ancien a expiré.

## Limite de l’essai

Le portefeuille, les QR codes, les ventes, les recharges, les reçus et les graphiques ne sont pas encore reliés aux tables Supabase. Ils ne sont pas disponibles dans l’essai connecté. N’utilisez pas cette version pour enregistrer des ventes ou des mouvements d’argent. Le backend complet doit être raccordé et revu avant un pilote financier.

## Mise à jour sur GitHub / Cloudflare Pages

1. Décompressez l’archive.
2. Dans GitHub, ouvrez `cantine-wallet-demo`, entrez dans le dossier `wero-wallet`, puis téléversez le contenu du dossier `wero-wallet-auth-update` en remplaçant les fichiers existants.
3. Validez le commit. Cloudflare Pages redéploiera le site automatiquement.
4. Ouvrez `https://cantine-wallet-demo.pages.dev`, cliquez sur « Mot de passe oublié ? », demandez un nouveau lien et ouvrez-le depuis le même navigateur.

Conservez dans Cloudflare les deux variables publiques déjà définies : `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`. Ne placez jamais la clé `service_role` dans le site.
