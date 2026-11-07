# Déployer la passerelle Somfy sur Cloudflare Workers

Aucune installation nécessaire : tout se fait dans le navigateur.
(Les intitulés de l'interface Cloudflare peuvent légèrement varier.)

## 1. Générer la clé de la montre

Dans le Terminal :

```bash
openssl rand -hex 24
```

Garde cette valeur : c'est `API_KEY`. Elle servira dans le Worker et dans l'app de la montre.

## 2. Créer le Worker

1. Crée un compte gratuit sur https://dash.cloudflare.com (le plan *Free* suffit).
2. **Workers & Pages** → **Create** → **Create Worker** (modèle *Hello World*).
3. Nom : `somfy-alarme` → **Deploy**.
4. **Edit code** → remplace tout le contenu par celui de `worker.js` → **Deploy**.

L'adresse du Worker ressemble à `https://somfy-alarme.<ton-sous-domaine>.workers.dev`.

## 3. Ajouter les secrets

Dans le Worker : **Settings** → **Variables and Secrets** → **Add**, type **Secret** :

| Nom              | Valeur                                   |
|------------------|------------------------------------------|
| `SOMFY_USER`     | ton e-mail Somfy Protect                 |
| `SOMFY_PASSWORD` | ton mot de passe Somfy Protect           |
| `API_KEY`        | la clé générée à l'étape 1               |
| `SOMFY_SITE_ID`  | *(seulement si tu as plusieurs sites)*   |

Les secrets sont chiffrés et ne sont plus lisibles après enregistrement.

## 4. (Recommandé) Garder le jeton Somfy entre deux appels

Sans cette étape, tout fonctionne, mais le Worker se reconnecte avec ton mot de passe
à chaque redémarrage au lieu de réutiliser son jeton.

1. **Storage & Databases** → **KV** → **Create** → nom `somfy-tokens`.
2. Dans le Worker : **Settings** → **Bindings** → **Add** → **KV namespace**,
   nom de variable `TOKENS`, espace `somfy-tokens`.

## 5. Tester

Remplace l'adresse et la clé :

```bash
curl -H "Authorization: Bearer TA_CLE" https://somfy-alarme.TON-SOUS-DOMAINE.workers.dev/status
```

Réponse attendue : `{"site":"Maison","status":"disarmed","confirmed":true}`

Puis, si tu veux tester une action :

```bash
curl -X POST -H "Authorization: Bearer TA_CLE" https://somfy-alarme.TON-SOUS-DOMAINE.workers.dev/partial
```

| Route          | Méthode | Effet               |
|----------------|---------|---------------------|
| `/status`      | GET     | état actuel         |
| `/arm`         | POST    | armement total      |
| `/partial`     | POST    | armement partiel    |
| `/disarm`      | POST    | désarmement         |

En cas de problème, la réponse contient `{"error": "..."}` ; les journaux sont
visibles dans le Worker, onglet **Logs**.
