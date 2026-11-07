#!/usr/bin/env python3
"""Pilotage de l'alarme Somfy Protect en ligne de commande.

Usage :
    python3 somfy_alarme.py statut
    python3 somfy_alarme.py on        # armement total
    python3 somfy_alarme.py partiel   # armement partiel (mode nuit)
    python3 somfy_alarme.py off       # désarmement
    python3 somfy_alarme.py sites     # liste les sites du compte
    python3 somfy_alarme.py logout    # supprime le jeton enregistré

Identifiants : variables d'environnement SOMFY_USER / SOMFY_PASSWORD,
sinon ils sont demandés au clavier. Le mot de passe n'est jamais écrit
sur disque : seul le jeton OAuth (renouvelable) est conservé, en 600,
dans ~/.config/somfy-alarme/token.json.

S'appuie sur l'API non officielle utilisée par l'app mobile Somfy Protect
(api.myfox.io). Somfy peut la modifier sans préavis.

Uniquement la bibliothèque standard Python (3.9+).
"""

import base64
import getpass
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional

API_URL = os.environ.get("SOMFY_API_URL", "https://api.myfox.io")
TOKEN_URL = os.environ.get("SOMFY_TOKEN_URL", "https://sso.myfox.io/oauth/oauth/v2/token")
TOKEN_FILE = Path(os.environ.get(
    "SOMFY_TOKEN_FILE", Path.home() / ".config" / "somfy-alarme" / "token.json"))

# Identifiants OAuth publics de l'app mobile, repris de la bibliothèque
# open source somfy-protect-api (utilisée par l'intégration Home Assistant).
CLIENT_ID = base64.b64decode(
    "ODRlZGRmNDgtMmI4ZS0xMWU1LWIyYTUtMTI0Y2ZhYjI1NTk1XzQ3NWJ1cXJmOHY4a2d3b280"
    "Z293MDhna2tjMGNrODA0ODh3bzQ0czhvNDhzZzg0azQw").decode()
CLIENT_SECRET = base64.b64decode(
    "NGRzcWZudGlldTB3Y2t3d280MGt3ODQ4Z3c0bzBjOGs0b3djODBrNGdvMGNzMGs4NDQ=").decode()

USER_AGENT = "Somfy Protect"

# Commande CLI -> valeur attendue par l'API
COMMANDES_ETAT = {"on": "armed", "partiel": "partial", "off": "disarmed"}
LIBELLES = {"armed": "ARMÉE (total)", "partial": "ARMÉE (partiel)", "disarmed": "DÉSARMÉE"}


class SomfyError(Exception):
    pass


class AuthError(SomfyError):
    pass


def _http(method: str, url: str, *, form: Optional[Dict[str, str]] = None,
          body: Optional[Dict[str, Any]] = None, token: Optional[str] = None) -> Any:
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    data = None
    if form is not None:
        data = urllib.parse.urlencode(form).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    elif body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:300]
        if e.code in (400, 401, 403):
            raise AuthError(f"HTTP {e.code} : {detail}") from None
        raise SomfyError(f"HTTP {e.code} sur {url} : {detail}") from None
    except urllib.error.URLError as e:
        raise SomfyError(f"Connexion impossible à {url} : {e.reason}") from None
    return json.loads(raw) if raw else {}


class SomfyClient:
    """Client minimal réutilisable (le futur serveur pour la montre s'en servira)."""

    def __init__(self, username: Optional[str] = None, password: Optional[str] = None,
                 token_file: Path = TOKEN_FILE):
        self.username = username
        self.password = password
        self.token_file = Path(token_file)
        self.token: Optional[Dict[str, Any]] = self._load_token()

    # --- gestion du jeton -------------------------------------------------
    def _load_token(self) -> Optional[Dict[str, Any]]:
        try:
            return json.loads(self.token_file.read_text())
        except (OSError, ValueError):
            return None

    def _save_token(self, tok: Dict[str, Any]) -> None:
        tok = dict(tok)
        tok["expires_at"] = time.time() + int(tok.get("expires_in", 3600)) - 60
        self.token = tok
        self.token_file.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.token_file.with_suffix(".tmp")
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            json.dump(tok, f)
        os.replace(tmp, self.token_file)

    def logout(self) -> None:
        self.token = None
        try:
            self.token_file.unlink()
        except FileNotFoundError:
            pass

    def _login(self) -> None:
        if not self.username or not self.password:
            raise AuthError("identifiants requis")
        tok = _http("POST", TOKEN_URL, form={
            "grant_type": "password",
            "username": self.username,
            "password": self.password,
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
        })
        if "access_token" not in tok:
            raise AuthError(f"réponse inattendue : {tok}")
        self._save_token(tok)

    def _refresh(self) -> bool:
        if not self.token or not self.token.get("refresh_token"):
            return False
        try:
            tok = _http("POST", TOKEN_URL, form={
                "grant_type": "refresh_token",
                "refresh_token": self.token["refresh_token"],
                "client_id": CLIENT_ID,
                "client_secret": CLIENT_SECRET,
            })
        except AuthError:
            return False
        if "access_token" not in tok:
            return False
        tok.setdefault("refresh_token", self.token["refresh_token"])
        self._save_token(tok)
        return True

    def _access_token(self) -> str:
        if self.token and self.token.get("expires_at", 0) > time.time():
            return self.token["access_token"]
        if not self._refresh():
            self._login()
        return self.token["access_token"]  # type: ignore[index]

    def _api(self, method: str, path: str, body: Optional[Dict[str, Any]] = None) -> Any:
        try:
            return _http(method, API_URL + path, body=body, token=self._access_token())
        except AuthError:
            # jeton révoqué ou expiré côté serveur : on retente une fois
            if not self._refresh():
                self._login()
            return _http(method, API_URL + path, body=body, token=self._access_token())

    # --- API ---------------------------------------------------------------
    def sites(self) -> List[Dict[str, Any]]:
        return self._api("GET", "/v3/site").get("items", [])

    def site(self, site_id: str) -> Dict[str, Any]:
        return self._api("GET", f"/v3/site/{site_id}")

    def set_security(self, site_id: str, status: str) -> Any:
        if status not in LIBELLES:
            raise ValueError(f"état inconnu : {status}")
        return self._api("PUT", f"/v3/site/{site_id}/security", {"status": status})


# --- ligne de commande -----------------------------------------------------
def _choisir_site(client: SomfyClient) -> Dict[str, Any]:
    sites = client.sites()
    if not sites:
        raise SomfyError("aucun site sur ce compte")
    wanted = os.environ.get("SOMFY_SITE_ID")
    if wanted:
        for s in sites:
            if s.get("site_id") == wanted:
                return s
        raise SomfyError(f"site {wanted} introuvable (voir la commande 'sites')")
    if len(sites) > 1:
        raise SomfyError("plusieurs sites : définissez SOMFY_SITE_ID (voir la commande 'sites')")
    return sites[0]


def _afficher(site: Dict[str, Any]) -> None:
    niveau = site.get("security_level", "?")
    print(f"{site.get('label', site.get('site_id'))} : {LIBELLES.get(niveau, niveau)}")


def _executer(client: SomfyClient, cmd: str) -> int:
    if cmd == "sites":
        for s in client.sites():
            niveau = s.get("security_level")
            print(f"{s.get('site_id')}  {s.get('label')}  ({LIBELLES.get(niveau, niveau)})")
        return 0
    site = _choisir_site(client)
    if cmd == "statut":
        _afficher(site)
        return 0
    return _changer(client, site, COMMANDES_ETAT[cmd])


def main(argv: List[str]) -> int:
    commandes = ["statut", "sites", "logout", *COMMANDES_ETAT]
    if len(argv) != 1 or argv[0] not in commandes:
        print(__doc__.split("\n\n")[1])
        return 2
    cmd = argv[0]

    client = SomfyClient(os.environ.get("SOMFY_USER"), os.environ.get("SOMFY_PASSWORD"))
    if cmd == "logout":
        client.logout()
        print("Jeton supprimé.")
        return 0

    def demander_identifiants(message: str = "Mot de passe : ") -> None:
        if not client.username:
            client.username = input("E-mail Somfy Protect : ").strip()
        if not client.password:
            client.password = getpass.getpass(message)

    # Identifiants demandés seulement s'il n'y a aucun jeton enregistré.
    if client.token is None:
        demander_identifiants()

    try:
        try:
            return _executer(client, cmd)
        except AuthError:
            if client.password:
                raise
            # Jeton enregistré devenu invalide : on redemande le mot de passe.
            client.logout()
            demander_identifiants("Session expirée. Mot de passe : ")
            return _executer(client, cmd)
    except AuthError as e:
        print(f"Échec d'authentification : {e}", file=sys.stderr)
        return 1
    except SomfyError as e:
        print(f"Erreur : {e}", file=sys.stderr)
        return 1


def _changer(client: SomfyClient, site: Dict[str, Any], status: str) -> int:
    client.set_security(site["site_id"], status)
    print(f"Demande envoyée : {LIBELLES[status]}")
    # L'API traite la demande de façon asynchrone : on vérifie quelques secondes.
    for _ in range(5):
        time.sleep(2)
        actuel = client.site(site["site_id"]).get("security_level")
        if actuel == status:
            print(f"Confirmé : alarme {LIBELLES[status]}")
            return 0
    print(f"Pas encore confirmé (état actuel : {LIBELLES.get(actuel, actuel)}). "
          "Relancez 'statut' dans un instant.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
