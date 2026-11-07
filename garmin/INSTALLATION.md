# App « Alarme Somfy » — installation

Montres prises en charge : fēnix 8, Venu 4, epix 2 (liste complète et description
fonctionnelle dans le [README](../README.md)).

## 1. Installer les outils (une seule fois)

1. **Java** : JDK *Temurin 17* (ou plus récent), fichier `.pkg` pour macOS,
   depuis https://adoptium.net
2. **SDK Connect IQ** : *SDK Manager* depuis https://developer.garmin.com/connect-iq/sdk/
   - Connexion avec un compte Garmin.
   - Onglet **SDKs** : dernière version → **Use as current SDK**.
   - Onglet **Devices** : télécharger les modèles voulus.

## 2. Régler l'adresse et la clé

```bash
cp properties.example.xml resources/settings/properties.xml
```

Dans `resources/settings/properties.xml`, remplacer
`https://somfy-alarme.TON-SOUS-DOMAINE.workers.dev` et `TA_CLE` par l'adresse du Worker
et la clé `API_KEY`. Ce fichier est ignoré par git : ne pas le partager.

## 3. Compiler et tester

```bash
./build.sh sim fenix847mm
```

compile et lance le simulateur. Dans le simulateur, l'app passe par le Mac pour joindre
le Worker.

## 4. Installer sur la montre

```bash
./build.sh fenix847mm
```

produit `bin/SomfyAlarme.prg` pour le modèle indiqué :

| Modèle | Identifiant |
|---|---|
| fēnix 8 AMOLED 43 / 47 mm | `fenix843mm` / `fenix847mm` |
| fēnix 8 Pro 47 mm | `fenix8pro47mm` |
| fēnix 8 Solar 47 / 51 mm | `fenix8solar47mm` / `fenix8solar51mm` |
| Venu 4 41 / 45 mm | `venu441mm` / `venu445mm` |
| epix (Gen 2) | `epix2` |
| epix Pro (Gen 2) 42 / 47 / 51 mm | `epix2pro42mm` / `epix2pro47mm` / `epix2pro51mm` |

Ensuite :

1. Quitter **Garmin Express** s'il est ouvert, brancher la montre en USB.
   Sur macOS, la montre n'apparaît pas dans le Finder : utiliser **OpenMTP**
   (https://openmtp.ganeshrvel.com).
2. Copier `SomfyAlarme.prg` dans le dossier `GARMIN/APPS` de la montre.
3. Débrancher : l'app apparaît dans la liste des aperçus (sinon :
   *Réglages › Apparence › Aperçus › Ajouter*).

## Fichiers à garder privés (ignorés par git)

- `developer_key.der` : clé de signature, générée par `build.sh` si absente.
  À sauvegarder : elle est nécessaire pour mettre à jour l'app sans la désinstaller.
- `resources/settings/properties.xml` : adresse du Worker et clé API.
