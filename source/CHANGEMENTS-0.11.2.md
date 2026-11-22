# Vidéo Club 0.11.2 — retours du 22 novembre

- Démarrage Android/Quest en mode entrepreneur : sauvegarde entrepreneur existante proposée, nouvelle partie séparée sinon. Le choix explicite d’un autre mode dans les menus reste possible. Accroupissement VR moins bas : cible de caméra à 95 cm au lieu de 60 cm, sans modifier les mouvements réels du casque.
- Ordinateurs agrandis, trois grandes fiches par page, affiches et textes plus grands, flèches haut/bas et joystick de défilement. Genres et types dans des pastilles de couleur stable; contraste du texte testé sur tous les genres du catalogue.
- Commandes immédiatement disponibles au backstore; regroupement des films dans les cartons non ouverts jusqu’à 20 unités. Les cartons d’étagère peuvent se transporter et se poser avant ouverture. Le contenu utilise les formes et les imprimés des véritables boîtiers du jeu.
- Montage à l’endroit où le carton est posé, y compris sur l’établi du backstore. Prise à la poignée, emplacement suivant jaune, relâchement pour enclencher la planche. Une planche relâchée ailleurs a une physique et peut être reprise. Dix vis aux jonctions réelles des tablettes, vissables dans l’ordre choisi. Corrections des surfaces qui s’interpénétraient et du bruit excessif des normales.
- Étagère construite déplaçable ensuite, placement à la grille/45°, restrictions près des murs corrigées. Première place en rayon choisie au dépôt du film, places libres indiquées, occupation synchronisée et sauvegardée.
- Backstore réaménagé : stockage métallique, cartons étiquetés, tableau de travail, bureau CRT, affiches, matériaux de mur, sol et établi. Les meubles de travail ont des collisions.
- Plantes, deux distributrices et téléviseurs deviennent des achats à placer en mode entrepreneur; une TV de démonstration reste en place. Les modèles originaux et la physique des gommes sont réutilisés. Un seul flux vidéo est partagé entre les téléviseurs.
- Calendrier : titres aux dates annoncées, planification des prochaines sorties persistante. Le poignet montre l’heure et le budget disponible.
- Correction du transport de carton par un joueur Android invité, qui utilisait une ancienne position de main. Les nouveaux clients partagent la même révision de protocole et invitent les anciennes versions à se mettre à jour.
- Version de test allégée : trois bandes-annonces de fond seulement (les 57 autres fichiers restent dans les sources et ne sont pas supprimés). Aucune baisse de définition des pochettes ou des textures.

## Vérifications

14 scénarios Vulkan réussis, complétés par les scénarios OpenGL Android : nouveau parcours vidéo, montage/déballage, coop entrepreneur et transaction coop complète. La vérification de contraste couvre tous les genres. Les avertissements de textures à la fermeture OpenGL sont conservés dans les rapports.

Ces essais logiciels ne mesurent pas les FPS dans un Quest porté. Le rôle invité VR natif demeure une limite connue; la coop testée couvre l’hôte Quest/Android et l’invité Android. Le mode PC n’est pas exporté dans cette mise à jour.

Sauvegardes locales avant changement : backups/pre-0112-20261122 et backups/quest-pre-0112-userdata.tar. Les sources et les bandes-annonces complètes demeurent sauvegardées sur GitHub.
