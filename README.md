# Orbis

Fusionne les orbes, fais tourner l'arène, atteins la forme finale.

Jeu mobile (Android) inspiré des vidéos de « simulation de balles » : des orbes à visage tombent dans une arène néon arc-en-ciel. Deux orbes identiques fusionnent en un orbe plus grand. Chaque rebond joue une note de musique.

## Installer sur ton téléphone

À chaque mise à jour de `main`, GitHub compile l'APK et le publie dans la release **Aperçu** :
https://github.com/tekelisifa/orbis/releases/download/apercu/orbis.apk

## Modes

| Mode | Ce que contrôle le joueur | Défaite |
|---|---|---|
| **Orbite** | Il fait tourner l'arène du doigt. Les orbes apparaissent seuls ; l'arène a une ouverture | 3 orbes échappés |
| **Chute** | Il vise et lâche l'orbe suivant, comme le jeu de la pastèque, mais dans un cercle | La pile reste au-dessus de la ligne rouge |

## Les 11 formes

Étincelle → Goutte → Bulle → Lune → Corail → Braise → Anneaux → Océan → Géante → Étoile → **Supernova**.
Deux supernovas qui se touchent déclenchent un **Big Bang**.

## Ce qui donne envie

- Arène néon arc-en-ciel avec halo, éclats lumineux à chaque rebond.
- Orbes à visage qui clignent, s'étonnent quand ils vont vite, sourient après une fusion.
- Traînées lumineuses, particules, ondes de choc, tremblement de l'écran, vibrations.
- Combos qui font monter l'arpège ; supernova au ralenti ; Big Bang.
- Musique : chaque rebond joue la note suivante d'une mélodie originale (gamme pentatonique). Aucune musique sous droits.
- Chaîne d'évolution en bas de l'écran : les formes non découvertes sont des « ? ».

## Vidéos promo générées par le jeu

Le jeu sait jouer tout seul et produire des vidéos verticales « simulation » prêtes à poster :

```
godot --path . --write-movie promo.avi --fixed-fps 60 --quit-after 2280 -- --record=chute
ffmpeg -i promo.avi -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -c:a aac promo.mp4
```

`--record=chute` ou `--record=orbite`. En mode Chute, le niveau des orbes monte avec le temps pour atteindre la supernova en une trentaine de secondes.

## Code

```
scripts/art.gd       direction artistique : textures, polices, les 11 formes, dessin des orbes
scripts/sfx.gd       sons générés (cloches, mélodie, arpèges, nappe)
scripts/game.gd      une partie : physique, fusions, combos, effets, modes, IA de démo
scripts/arena.gd     l'anneau néon et son ouverture
scripts/ball.gd      un orbe (corps physique, visage animé, traînée)
scripts/game_ui.gd   score, record, prochain orbe, vies, chaîne d'évolution, fin de partie
scripts/menu.gd      menu avec une partie qui se joue en fond
fonts/               Fredoka (licence OFL)
```

## À venir

- Exporter la vidéo de sa propre partie depuis le téléphone, pour la partager.
- Thèmes et skins (planètes, animaux, bonbons), mélodies à débloquer.
- Défi du jour, pub récompensée pour continuer, suppression des pubs.

## Crédits sons

- Miaulements (univers Chats) : « Miaulement de chat à la bouche », ID 0926, [La Sonothèque](https://lasonotheque.org), retravaillés (hauteur, grondement, écho) pour chaque taille de chat.
