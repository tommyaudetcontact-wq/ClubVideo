# Reprise — 19 novembre 2026

Nouvelle limite utilisateur : CONTINUER JUSQU’À30% RESTANT SUR LA FENÊTRE5H, donc ARRÊTER à70% utilisés. Cette limite remplace l’ancien arrêt à2%. Ne pas éteindre Windows à30%. Dernier relevé :66% utilisés.

## Fait aujourd’hui
- Affiches posables sur murs pleins avec aperçu, annulation conservant le colis, contrôle de chevauchement/obstacles, poses persistantes.
- Habitués : apparence liée au compte et propagée aux invités.
- Entrepreneur : rayures réellement constatées à l’inspection →3$ au dossier, une seule fois par location. Réclamation manuelle, aucun frais pour disque propre ou dommages préexistants. Aucun changement de cette règle dans le mode normal.
- Coop entrepreneur pour invités ANDROID : géométrie, rayons, inventaire, commandes/argent, construction complète, affiches et dossiers partagés. L’invité peut commander, recevoir, assembler6planches+4vis, placer une étagère et une affiche. Réservations acceptent les boîtiers de l’invité. Localisation jaune fonctionne aussi sur ses objets partagés.
- Changement automatique de mode pour rejoindre : sauvegarde locale protégée, chargement entrepreneur puis retour au mode et à la sauvegarde d’origine au départ. Test réel de rechargement de scène réussi.
- Clés de copies entrepreneur stables E|id, seuls les exemplaires possédés envoyés. Budget de rendu local restauré au départ.
- Calendrier papier dessiné : dates, croix, cercle, prochaines sorties/lots. Rendu mis à jour seulement sur changement.
- Bureau CRT détaillé, clavier regroupé en une passe, pieds/tiroirs et collisions des tables.
- Contrôle de révision du catalogue dans le protocole : anciens catalogues refusés pour éviter des contenus différents entre joueurs.

## Tests
`work/regression-results-gpu.json` :12/12 réussis (Vulkan), dont200titres/600faces/200disques.
`work/regression-results-compat-partial.json` :6/6 réussis (OpenGL Android simulé), incluant coop normale/entrepreneur, changement de mode et parcours tactiles.
Textures à la fermeture OpenGL toujours consignées, pas masquées comme erreurs d’exécution.
Utilisateur a explicitement choisi de continuer les tests logiciels, aucun Quest porté mesuré. Aucun 72FPS réel garanti.

## APK et sauvegardes
`outputs/VideoClub-VR-Quest3S-v0.11.0.apk` code89, packagehabituelcom.videoclub.quest. Installé avec succès, metadata vérifiée0.11.0. Ancienne sauvegarde copiée dans `backups/quest-pre-0110-userdata.tar` (29,8Mo). Pas de désinstallation.
`outputs/VideoClub-Android-Jeu-v0.11.0.apk` code41 packagehabituelcom.videoclub.android. SignaturesAPKvalidées ; même certificat que0.10.19.
`outputs/ClubVideo-source-v0.11.0.zip` 913869997octets, archive complète horscaches/générés/anciennes pochettes désactivées, ZIP vérifié.
`work/validation-apk0110.json` : tailles/SHA256,800texturesprésenteset60trailerspourlesdeuxAPK.
Updatersconst0.11.0surlesdeuxplateformes. Aucun buildPCmodifié.

## Publication EN COURS
`work/publish-0110.py` tourne, session exec11217 : crée release GitHub v0.11.0 EN BROUILLON/prerelease et téléverse2APK+source avec validationtaille/SHA256. Journal `work/publish0110.log`.
À la fin, crée `work/release0110-uploaded.json` avec IDreleaseetliens. Ne pas rendre public avant que les3assets soient vérifiés.
Le script utilise le préambule de work/publish-v065.py pour l’API/authentification GitCredentialManager ; ne jamais imprimer les identifiants.
Branche source `entrepreneur-200-films` déjàpoussée avec tousleschangementsdecode. `outputs/clubvideo-downloads/index.html` a été modifié localement pour les liens0.11.0, et source/ENTREPRENEUR-EN-COURS.md misàjour, mais ces derniers changements doivent encoreêtrecommit/push.
Après validationdestroisassets : PATCH release draft=false (prerelease=true), puis commitpage/docs, fusion fast-forward de branche sur main et push pourGitHubPages. Vérifierlesliensdelapage. Les versions publiques sont encore0.10.11Quest/0.10.5Android tantquececi n’estpasfait.

## Limites et suite
Le rôle INVITÉ VR NATIF n’est PAS implémenté dans le client d’origine : la coop testée couvre Quest ou Android hôte, Android invité. Ne pas prétendre Quest↔Questvalidé. Ce point reste à compléter après le jalon0.11.0.
Les mesures Quest porté et validation visuelle dans casque restent à faire. L’utilisateur a décliné ces essais aujourd’hui.
Image revue : `work/backstore-20261119.png` ; prise avant l’ajout final des pieds/tiroirs.
SkillGDScriptutilisé, pas d’agentssecondairesautorisés.
