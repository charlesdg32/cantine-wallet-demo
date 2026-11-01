# La Cantine — essai interne

Cette version sert à tester les **demandes de compte et les rôles** avec 2 ou 3 personnes réelles. Les noms et comptes de démonstration ont été retirés. Une demande contient le nom et prénom, l’adresse e-mail et le mot de passe choisis par la personne. Le mot de passe est géré par Supabase Auth ; l’association ne peut pas le consulter.

## Ce qui est actif dans l’essai

- Inscription avec nom, adresse e-mail et mot de passe.
- Confirmation d’adresse si elle est activée dans Supabase.
- Comptes créés en attente jusqu’à approbation d’un administrateur.
- Attribution des rôles Adhérent, Membre actif, Trésorier et Administrateur.
- Les demandes réelles apparaissent dans Administration → Adhérents.

## Limite importante

Le portefeuille, les QR codes, les ventes, les recharges, les reçus et les graphiques ne sont **pas encore connectés aux tables Supabase**. Ils ne sont donc pas disponibles dans l’essai connecté. N’utilisez pas cette version pour enregistrer des ventes ou des mouvements d’argent. La base comporte des fonctions SQL prévues pour certaines opérations, mais l’application ne les utilise pas encore toutes ; le backend complet doit être raccordé et revu avant un pilote financier.

## Mise à jour sur Cloudflare Pages

1. Décompressez cette archive.
2. Dans GitHub, ouvrez le dépôt `cantine-wallet-demo`, entrez dans `wero-wallet`, puis téléversez le contenu du dossier `wero-wallet-auth-update` en remplaçant les fichiers existants (gardez `wero-wallet` comme dossier racine du projet).
3. Validez le commit. Cloudflare Pages redéploiera le site automatiquement.
4. Ouvrez le site et créez d’abord une demande pour vous-même si nécessaire. Dans Supabase, confirmez votre adresse, puis attribuez-vous le rôle administrateur avec la procédure déjà utilisée.
5. Faites inscrire les 2 ou 3 testeurs eux-mêmes. Vérifiez leurs noms et adresses, puis approuvez chaque compte et choisissez son rôle dans Administration → Adhérents.

Pour créer un nouveau compte interne, la personne doit demander l’accès sur le site avec son adresse réelle. Ne partagez pas de mot de passe par message.

## Paramètres Supabase et Cloudflare

Conservez les deux variables publiques déjà définies dans Cloudflare : `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`. N’ajoutez jamais la clé `service_role` au site. Dans Supabase Auth, l’inscription par e-mail doit être activée et l’URL `https://cantine-wallet-demo.pages.dev` autorisée dans les redirections.

L’URL de site affichée par Cloudflare est `https://cantine-wallet-demo.pages.dev`.
