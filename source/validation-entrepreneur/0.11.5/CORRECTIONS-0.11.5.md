# 0.11.5 — corrections locales des vidéos 205602 et205730

Aucune publication GitHub. Sauvegarde avant changements : backups/pre-0115.

- Déplacement étagères : agripper le cadre active le placement au sol; viser l'emplacement et confirmer à la gâchette. Appuyer à nouveau sur la poignée fait tourner par45°. Relâcher ne pose plus le meuble par accident. L'élévation et l'inclinaison de la main ne soulèvent plus le meuble.
- Grille10cm/45°, accroche aux murs minces des colliders, et accrochage des bords entre étagères parallèles conservant l'orientation45° volontaire. Contrôles d'obstacles et de passages conservés.
- Pochettes HD : ajout lod_slots (identité record par instance de papier) et refresh_cover_poses, mise à jour directe des MultiMesh sans recalcul de LOD ni rechargement de texture. preview_stock déplace boîtiers/coques/locks ET les vraies faces HD. Replica invité met également à jour le preview des films pendant un déplacement reçu.
- Carton d'étagère : ouverture conserve la boîte en main et affiche un choix de site. Aucune planche/structure n'apparaît avant confirmation du lieu. Le montage et la prise planche par planche restent inchangés après confirmation.
- Meuble fini : conserve les20vis aux mêmes transformations Build.screw_pose que le montage. Marqueurs Screw0..19 gardés pour validation; géométrie aplatie puis groupée par matériau, sans80drawcalls ajoutés. Vissage physique par mèche inchangé.
- Accroupissement artificiel : passage immédiat et stable vers la hauteur basse; suppression de la descente/remontée progressive de la caméra. Suivi physique de la tête conservé.
- Protocole catalogue4, Quest0.11.5/code94, Android0.11.5/code46.

Tests réussis GPU : nouveau test_entrepreneur_feedback115 (vraie instance de pochette HD déplacée, choix site après ouverture, vingt vis finales, mode placement au sol, confirmation, grille/accroche45°, accroupissement), feedback113 adapté au placement, workflow VR+tactile, coop TCP deux instances. Tests OpenGL : feedback115, feedback112 et vidéo antérieure adaptés au choix du site, démarrage. Avertissements de textures en fin d'arrêt GL conservés dans rapports. Pas de mesure de FPS réelle courante.

Compilation finale Quest en cours session52435 après dernière retouche replica. Android encore à produire avec ce code exact, puis installation Quest. Ne pas annoncer final prêt avant vérification.

TERMINÉ localement : APK Quest0.11.5/code94 installé avec succès et relancé; packageversion vérifiée. APK Android0.11.5/code46 prêt, non installé sur téléphone. Quest756433359octets, Android750560599octets. ZIP CRC sans erreur, exactement3OGV chacun; signature historique SHA256aa4edf2c6ec641a1317f2920d4c42d543c8162cba2531b33f6457b42158482ce vérifiée. Rapports work/validation-apk0115.json et source-0115-final.json. Aucune publication GitHub et aucune exportation PC.
Question asynchrone envoyée pour tester placement/rotation45°/pochettes réelles. Pas de retour matérielfinal ni de nouvelles mesuresFPS à ce stade. Ne pas citer anciens diagnostics comme actuels.
