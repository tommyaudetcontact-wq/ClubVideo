# Version 0.9.7 — Reprise du disque réparé sur Android

- Le toucher de la surfaceuse et l’action Reprendre le disque passent avant l’emplacement de disque invisible d’un boîtier vide ouvert.
- La récupération explicite fonctionne aussi si le boîtier reste ouvert; les disques invisibles ne capturent plus la sélection.
- Après récupération, le disque est marqué comme venant de la surfaceuse. Regarder encore la machine ne relance pas automatiquement une réparation. Ranger le disque remet le même disque dans le boîtier vide.
- Libellés Reprendre le disque et Réparation en cours selon l’état de la machine, synchronisés chez l’invité.

Validation : test Android utilisant le vrai parcours de toucher, boîtier vide ouvert pendant la réparation, récupération, identité et état du disque conservés, réinsertion; simulations complètes coop avec hôte Quest puis hôte Android.
