# Reprise — Club Vidéo — 18 novembre 2026

## État et autorisations
Continuer le mode entrepreneur et les 200 films fictifs ; retirer les vrais films/jeux de TOUS les modes, conserver uniquement les vraies bandes-annonces en fond. User veut tests exhaustifs. Quest connecté `340YC10G9Z0GQ4` mais en veille, aucune réponse au test porté. Dernière demande utilisateur : « j’ai branché le casque fait les test que tu veux ».

Condition d’arrêt demandée : quand la fenêtre Codex de 5 h atteint >=98 % utilisés (<=2 % restants), sauvegarder puis éteindre Windows. Dernière mesure : 95 % utilisés. Lire `mcp__codex_app__get_usage_limits`, ne jamais déduire le quota des tokens du modèle. Ne pas utiliser les crédits de reset. Aucun goal n’a été créé.

## Résultats
- 200 films fictifs, 800 textures. Ne pas régénérer les illustrations, elles sont approuvées.
- 9 scénarios sans affichage réussis (`work/regression-results.json`).
- 9 scénarios Vulkan + stress 200 titres réussis (`work/regression-final-gpu.json`).
- OpenGL compatible Android : tests disque et interactions réussis, parcours entrepreneur standard et tactile réussis. Ce dernier comprend commande/assemblage/placement, catégorie, 8 films, caisse réelle avec monnaie, sauvegarde/rechargement d’un retour NON scanné, localisation, scan, réservation par téléphone, rack, annulation, recommandation.
- Stress : 600 faces + 200 disques, cache papier max32, LOD max54, aucune erreur de scénario.
- 400 journées d’économie simulées : 203 lots, 24 nouveautés, prix/remises/calendrier corrects.
- Les tests OpenGL rapportent encore des textures lors de la FERMETURE du moteur. Le runner ne masque que ce message précis APRÈS le marqueur de réussite, et l’enregistre dans `teardown_warnings`. Toute autre erreur est un échec. La tentative de nettoyage des caches n’a rien réglé et est restée seulement dans le projet de test puis a été annulée par copie de main.gd original.
- Aucun FPS réel Quest mesuré. Le jeu TEST n’a jamais démarré : casque endormi et dialogue système signalé. Les FPS VrApi lus étaient ceux du menu Meta ! Ne pas les attribuer au jeu.

## Modifications dans cette reprise
`club_lan.gd` : prise de monnaie sans client actif utilisait `.active.id`, remplacé par `.get("id",-1)`. Scénario coop complet réussit après correction.
`club_save.gd` : migration des anciens titres vers le catalogue fictif, préserve copies, disques, prêts et finances quand le nombre de copies concorde. Si layout différent, ancien fichier conservé incompatible. Test dédié réussi GPU et sans affichage.
`entrepreneur_world.gd` : retire les pieds des anciens rayons y>.001, plus de triangles au sol ; nouvelles étagères regroupées en trois matériaux en préservant métal/roughness et couleurs.
`entrepreneur_state.gd` et calendrier : nombre de jours exact et année réelle après 2012. Tests 400 jours.
`club_entrepreneur.gd` : nouveautés/affiches/bonnes catégories augmentent sélection pondérée, titres distincts. Recommandations choisissent maintenant un exemplaire réellement disponible ; correctif ajouté APRÈS construction des dernières APK, donc source plus récente !
Tests ajoutés : `test_catalogue_migration.gd`, `test_catalogue_stress.gd`, `test_entrepreneur_rules.gd`, `test_entrepreneur_flow.gd` étendu. Deux tests coop figent le paiement à20$ pour éviter de dépendre du hasard du montant exact.
Runner `work/run-regression.py` : isolation données utilisateur, limites de temps, exige marqueur + pas d’erreur, modes headless/Vulkan/OpenGL ; les rapports partiels ne remplacent plus les rapports complets.

## APK de diagnostic (pas publication finale)
`outputs/VideoClub-Quest-preview.apk` : version `0.11.0-preview.2`, code2, package `com.videoclub.quest.preview`, nom « Vidéo Club TEST », 1 134 700 589 octets.
`outputs/VideoClub-Android-preview.apk` : version `0.11.0-preview.1`, code1, package `com.videoclub.android.preview`, 1 128 827 829 octets.
Les deux builds réussissent, 800 textures présentes et 60 vidéos .ogv préservées. Anciennes pochettes/disques/Netflix/atlas exclus (économie ~190Mo). Validation+SHA `work/apk-preview-validation.json`.
Quest preview1 avait été installé avec succès. Transfert preview2 en cours/à vérifier : `work/quest-preview2-install.log`, session exec40513. Aucune désinstallation de la version habituelle `.quest`, qui reste 0.10.19.
Les presets officiels/version d’update restent anciens, aucune release publique ni page de téléchargement modifiée. Le dernier correctif de recommandation n’est PAS dans ces APK de diagnostic. Ne pas les présenter comme finales.

## GitHub
Branche créée et poussée : `entrepreneur-200-films`, dépôt `outputs/clubvideo-downloads`, distant `tommyaudetcontact-wq/ClubVideo`.
Commit e34a9ec : checkpoint avec sources et les 800 textures. La branche contient les instructions `source/ENTREPRENEUR-EN-COURS.md`.
Actualiser encore les nouveaux tests, correction recommandation, presets, derniers rapports et runner puis commit/push. La branche main et sa page de téléchargement sont inchangées.

## Tests isolés
`work/test-project` copie des scripts racine et project.godot ; jonctions vers assets/addons/.godot. Dossier utilisateur personnalisé `ClubVideo-AutomatedTests-20261118`. Ne pas lancer les anciens tests sur le vrai dossier utilisateur (certaines clôtures sauvegardent même en mode tools).
Godot console `C:/Users/recto/Documents/Codex/2026-10-27/fait-x20-2/work/tools/godot/Godot_v4.7.2-stable_win64_console.exe`. Toujours `--xr-mode off` sur PC, sinon VD bloque.
ADB même base `work/tools/android-sdk/platform-tools/adb.exe`, Java `work/tools/jdk/jdk-17.0.20.1+1`.
Pour lancer TEST : `adb -s ... shell monkey -p com.videoclub.quest.preview -c android.intent.category.LAUNCHER 1`. L’activité interne GodotApp n’est pas exportée, passer par le launcher. Ne pas forcer des permissions ou simuler une personne portant le casque pour annoncer de faux FPS.

## Restant avant version finale
- Mesures Quest porté (fluidité/clarté/erreurs) et vraie manipulation entrepreneur.
- Entrepreneur coop non synchronisé (géométrie/stock/économie). Ne pas prétendre que les tests coop NORMAL valident entrepreneur coop.
- Affiches posables actuellement placées automatiquement, placement libre encore manquant.
- Frais de dommages entrepreneur et apparence cohérente des habitués à revoir.
- Revue visuelle du backstore et de tous les modèles, parcours de tutoriel.
- Recompiler les deux APK finales avec dernier source, version commune cohérente et signature officielle, publier source/release/pages uniquement une fois vérifiées.
- Photos PC : `work/catalogue-in-store.png`, `work/entrepreneur-empty-store.png` (dernière capture propre, pieds corrigés).
- Backup initial intact : `backups/avant-entrepreneur-20261118-150251`.

## Vérifications finales de cette séance
- Quest diagnostic `.preview` version0.11.0-preview.2/code2 installé avec succès (log `work/quest-preview2-install.log`). Version habituelle préservée.
- Les deux APK vérifiées par apksigner : signature v2 valide. Taille et SHA dans `work/apk-preview-validation.json`.
- Rapport consolidé fiable : `work/validation-summary-20261118.json` = 23 scénarios logiciels sur23 réussis. Il remplace les références aux rapports partiels dans les notes ci-dessus. Aucun FPS Quest porté mesuré.
- Dernier commit GitHub avant ce complément : d48e6da sur `entrepreneur-200-films`. La page publique et les APK publiques sont inchangées.
- Usage observé à97 % utilisés : prochain contrôle à faire avant de travailler davantage. À98 %, sauvegarder puis lancer `shutdown.exe /s /t 60` (sans /f), conformément à l’utilisateur.
