# Dose 💊

Ta checklist de compléments, en app iPhone native :

- **Widget écran d'accueil** (petit, moyen, grand) : tu coches directement dessus, avec des transitions animées.
- **Widget écran verrouillé** : un anneau qui coche le complément suivant, ou une ligne « prochain à prendre ».
- **Live Activity** : un grand bandeau coloré sur l'écran verrouillé et dans la Dynamic Island, avec un bouton par complément. Il disparaît tout seul quand tout est pris.
- **Dans l'app** : anneau animé, cartes qui rebondissent, série de jours 🔥, confettis quand tout est pris, retour haptique.
- **Rappels** à l'heure de chaque moment (matin, midi, soir, coucher), seulement s'il reste quelque chose à prendre, avec un bouton « C'est pris ✓ » directement dans la notification.
- **Alerte d'oubli** : si un complément n'est toujours pas coché un certain temps après l'heure prévue (1 h par défaut, réglable), tu reçois « Attention ⚠️ — T'as pas pris de Zinc ». Elle s'annule dès que tu coches, et le bouton « Dans 30 min » la repousse.
- **Pastille sur l'icône** = nombre de compléments restants aujourd'hui.
- **Suivi complet de chaque prise** : l'heure est enregistrée automatiquement, même quand tu coches depuis un widget ou l'écran verrouillé, avec la dose habituelle de chaque complément.
  - **Appui long sur une carte** pour modifier l'heure ou la dose du jour (par exemple 2 gélules au lieu d'une), ou retirer la prise.
- **Historique** (icône calendrier) :
  - un calendrier du mois coloré selon ce que tu as pris chaque jour ;
  - le détail d'un jour (quoi, à quelle heure, combien), avec « Marquer pris » pour rattraper un oubli de cocher ;
  - ta série actuelle, ta meilleure série et ta régularité sur 30 jours ;
  - pour chaque complément : nombre de jours pris, heure moyenne et quantité totale sur 30 jours ;
  - un **export CSV** (bouton en haut à gauche) qui s'ouvre dans Excel ou Numbers.

Les moments de prise de départ sont des suppositions, et les doses habituelles sont vides : renseigne-les dans **Réglages** (icône en haut à droite) → touche un complément. Tu peux aussi y changer les noms, couleurs, icônes et heures de rappel.

---

## Comment ça marche (sans Mac)

```
Ce dossier ──push──▶ GitHub ──Mac de GitHub──▶ Dose.ipa ──▶ SideStore (iPhone) ──signe──▶ app installée
```

1. **GitHub Actions** utilise un Mac dans le cloud pour compiler l'app. Il produit `Dose.ipa`, une app non signée, et la publie dans la page *Releases* du dépôt.
2. **SideStore**, sur ton iPhone, signe cette app avec ton identifiant Apple gratuit et l'installe.
3. La signature gratuite dure **7 jours** : SideStore la renouvelle. Il suffit de l'ouvrir et de toucher « Refresh », ou de l'automatiser (voir étape 5).

---

## Étape 1 — Mettre le projet sur GitHub

1. Crée un compte sur github.com si tu n'en as pas.
2. Crée un nouveau dépôt, par exemple `dose`. **Public** est le plus simple (minutes de Mac illimitées). En **privé**, tu as un quota gratuit de minutes Mac, largement suffisant pour quelques builds par mois.
3. Envoie le contenu de ce dossier dans le dépôt, sur la branche `main`. Le plus simple : glisser-déposer les fichiers via *Add file → Upload files*. Attention à bien inclure le dossier caché `.github`.

## Étape 2 — Lancer la compilation

1. Dans le dépôt, ouvre l'onglet **Actions**. Le workflow **Build Dose** démarre tout seul après chaque envoi. Tu peux aussi le relancer avec *Run workflow*.
2. Attends environ 5 à 10 minutes que la coche passe au vert.
3. En cas d'échec (croix rouge), télécharge l'artefact **build-log** en bas de la page du run et envoie-le-moi. Je ne peux pas compiler l'app de mon côté, donc il est possible qu'une petite erreur de compilation apparaisse au premier essai.
4. Une fois que c'est vert, la page **Releases** (colonne de droite du dépôt) contient `Dose.ipa`.

## Étape 3 — Installer SideStore (une seule fois, avec un ordi)

SideStore évolue souvent, donc suis le guide officiel : **https://docs.sidestore.io**. En résumé, il faut :
- activer le **mode développeur** sur l'iPhone (Réglages → Confidentialité et sécurité) ;
- utiliser l'outil d'installation de SideStore sur ton ordi (Windows ou Mac) pour l'installer sur l'iPhone, avec ton identifiant Apple ;
- installer l'app VPN locale demandée par SideStore : c'est elle qui permet ensuite de renouveler les apps sans ordi.

## Étape 4 — Installer Dose

1. Sur l'iPhone, ouvre la page *Releases* de ton dépôt dans Safari et télécharge `Dose.ipa`.
2. Dans SideStore → **My Apps** → **+** → choisis `Dose.ipa` dans Fichiers.
3. Ouvre Dose une fois, puis active les rappels dans Réglages.
4. Ajoute les widgets :
   - **Écran d'accueil** : appui long → **+** → Dose.
   - **Écran verrouillé** : appui long sur l'écran verrouillé → Personnaliser → zone des widgets → Dose.

### ✅ Le test important

Coche un complément **depuis le widget**, puis ouvre l'app : il doit apparaître coché.
- **Oui** → tout fonctionne. 🎉
- **Non** (le widget et l'app ne voient pas les mêmes coches) → le partage de données entre l'app et le widget (App Group) n'a pas survécu à la signature gratuite. Dis-le-moi : on a des solutions de repli.

## Étape 5 — Ne plus penser aux 7 jours

- Dans l'app **Raccourcis** → Automatisation → **+** → *Heure de la journée* (par exemple tous les jours à 7 h) → cherche une action **SideStore** du type « Refresh All Apps » → *Exécuter immédiatement*.
- Si l'action n'existe pas dans ta version de SideStore, ouvre simplement SideStore une fois par semaine et touche *Refresh All*.
- Si la signature expire quand même, Dose refuse de s'ouvrir jusqu'au prochain renouvellement, mais **tes données ne sont pas perdues**.

---

## Limites à connaître

- **Identifiant Apple gratuit** : 3 apps installées via SideStore au maximum (SideStore compris), et 10 identifiants d'app par semaine. Dose en utilise 2 (l'app et ses widgets).
- **La Live Activity** ne peut être lancée que lorsque l'app est ouverte : sans compte développeur payant, impossible de la faire apparaître à distance. C'est pour ça que l'option *Épingler à l'ouverture* existe : tu ouvres l'app via la notification du matin, et la checklist s'installe sur l'écran verrouillé. Elle reste au maximum 8 heures, comme toute Live Activity.
- **Rafraîchissement des widgets** : quand tu coches dans l'app, les widgets se mettent à jour tout de suite. Le passage à minuit dépend d'iOS et peut avoir quelques minutes de retard.
- **Les rappels** sont programmés sur 7 jours glissants et reprogrammés à chaque ouverture de l'app ou rafraîchissement du widget.

## Modifier l'app

Change les fichiers `.swift`, envoie-les sur GitHub, attends la nouvelle release, puis réinstalle `Dose.ipa` depuis SideStore. Tes coches et tes réglages sont conservés.

| Dossier | Contenu |
|---|---|
| `App/` | L'app : écran du jour, réglages, notifications |
| `Widgets/` | Widgets d'accueil, d'écran verrouillé et Live Activity |
| `Shared/` | Ce qui est commun : modèle, stockage, intents, rappels, couleurs |
| `project.yml` | Description du projet Xcode (générée par XcodeGen) |
| `.github/workflows/build.yml` | La compilation automatique sur un Mac de GitHub |
