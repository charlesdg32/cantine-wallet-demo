# La Cantine — version 12 connectée

Cette version ajoute un sélecteur d’emojis au formulaire d’ajout de produit. L’emoji choisi est enregistré dans Supabase et réapparaît sur les boutons de vente après actualisation. Les produits existants gardent l’emoji café par défaut. Le sélecteur fonctionne aussi en mode démo.

## Mise à jour

1. Dans Supabase, ouvre **SQL Editor → New query**.
2. Exécute le contenu de `supabase/product_emoji_migration.sql`. Cette migration ajoute une colonne `emoji` aux produits et attribue l’emoji café par défaut aux produits déjà présents.
3. Attends **Success**.
4. Dans GitHub, entre dans `wero-wallet` et remplace son contenu par les fichiers de la version 12. Garde les variables Cloudflare `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`.
5. Valide les changements dans GitHub et attends le déploiement vert de Cloudflare Pages.
6. Dans **Administration → Produits**, clique sur **Ajouter un produit**, choisis son emoji, puis indique son nom et son prix.

Les corrections QR de la version 10 et d’affichage mobile de la version 11 sont incluses. Si tu ne les as pas encore appliquées, exécute aussi leurs migrations SQL avant la mise à jour.

N’ajoute jamais une clé `service_role` dans Cloudflare Pages ou dans le code du navigateur. Les identifiants Brevo restent dans la configuration SMTP Supabase, pas dans GitHub.
