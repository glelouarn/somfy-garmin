#!/bin/bash
# Compile l'app pour la montre.  Usage : ./build.sh [id_appareil]
# Puis, pour le simulateur :  ./build.sh sim [id_appareil]
set -euo pipefail
cd "$(dirname "$0")"

CIQ="$HOME/Library/Application Support/Garmin/ConnectIQ"
SDK="$(cat "$CIQ/current-sdk.cfg" 2>/dev/null || true)"
SDK="${SDK%/}"
if [ -z "$SDK" ] || [ ! -x "$SDK/bin/monkeyc" ]; then
    SDK="$(ls -d "$CIQ"/Sdks/*/ 2>/dev/null | sort | tail -1 || true)"
    SDK="${SDK%/}"
fi
[ -x "$SDK/bin/monkeyc" ] || { echo "SDK Connect IQ introuvable (installe-le avec le SDK Manager)"; exit 1; }

PROPS=resources/settings/properties.xml
if [ ! -f "$PROPS" ]; then
    cp properties.example.xml "$PROPS"
    echo "Créé $PROPS depuis le modèle : renseigne serverUrl et apiKey, puis relance."
    exit 1
fi
if grep -q "TON-SOUS-DOMAINE\|>TA_CLE<" "$PROPS"; then
    echo "Attention : $PROPS contient encore les valeurs d'exemple (l'app affichera « Adresse/Clé non réglée »)."
fi
if [ ! -f developer_key.der ]; then
    echo "Pas de clé de signature : génération de developer_key.der (à conserver précieusement)."
    openssl genrsa -out developer_key.pem 4096 2>/dev/null
    openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
    rm -f developer_key.pem
    chmod 600 developer_key.der
fi

SIM=0
if [ "${1:-}" = "sim" ]; then SIM=1; shift; fi
DEVICE="${1:-fenix847mm}"

mkdir -p bin
"$SDK/bin/monkeyc" -f monkey.jungle -d "$DEVICE" -y developer_key.der -o bin/SomfyAlarme.prg -w
echo "OK : bin/SomfyAlarme.prg ($DEVICE)"

if [ "$SIM" = 1 ]; then
    open -a "$SDK/bin/ConnectIQ.app" 2>/dev/null || "$SDK/bin/connectiq" &
    sleep 4
    "$SDK/bin/monkeydo" bin/SomfyAlarme.prg "$DEVICE"
fi
