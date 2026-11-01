# La Cantine — version 11 connectée

Cette mise à jour corrige le rendu de la carte adhérent après scan : les initiales restent propres même sans nom de famille et la carte tient sur les écrans de téléphone. Elle corrige aussi le refus des QR des adhérents simples. Être « Membre actif » donne le droit de tenir la caisse ; cela ne doit pas conditionner l’usage du portefeuille. Le code adhérent est aussi de nouveau affiché sous le QR.

Le bouton « Pas encore inscrit ? » ouvre le formulaire de demande. Le prénom et le nom sont obligatoires et transmis au profil Supabase.

## Mise à jour du site

1. Dans Supabase, ouvre **SQL Editor → New query**.
2. Copie le contenu de `supabase/qr_member_access_fix.sql` dans l’éditeur, puis clique sur **Run**. Cette correction ne supprime aucune donnée ; elle met à jour la vérification QR et l’enregistrement d’une vente.
3. Attends **Success**. Si tu n’as jamais exécuté `qr_roles_live_migration.sql` de la version 8, exécute-le d’abord.
4. Dans GitHub, entre dans `wero-wallet` et remplace son contenu par les fichiers de la version 11. Garde les variables Cloudflare `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`.
5. Valide les changements dans GitHub et attends le déploiement vert de Cloudflare Pages.
6. Déconnecte-toi et reconnecte-toi sur le compte qui porte le QR. Scanne le nouveau code depuis un compte **Membre actif**, **Trésorier** ou **Administrateur**.

## Rôles

- **Adhérent** : compte, solde, historique et QR utilisable à la caisse.
- **Membre actif** : accès adhérent et outils de vente.
- **Trésorier** : ventes, demandes de recharge et suivi de trésorerie.
- **Administrateur** : gestion du site, des comptes, des rôles et des produits.

Les comptes doivent être approuvés. Le scanner nécessite une page HTTPS et l’autorisation de la caméra.

## Sécurité et limites

Supabase stocke une empreinte du secret QR, pas le secret en clair. Une reconnexion crée un QR neuf et invalide le précédent. Les reçus sont déposés dans un bucket privé. Cette version reste un essai interne : avant tout usage financier réel, faites examiner les règles d’accès, le rapprochement et les sauvegardes.

N’ajoute jamais une clé `service_role` dans Cloudflare Pages ou dans le code du navigateur. Les identifiants Brevo restent dans la configuration SMTP Supabase, pas dans GitHub.
