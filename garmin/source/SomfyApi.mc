import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;

// Appels à la passerelle Cloudflare (via l'app Garmin Connect du téléphone).
module SomfyApi {

    // Renvoie null si l'envoi est parti, sinon un message d'erreur de configuration.
    function request(path as String, isPost as Boolean, callback as Method) as String or Null {
        var url = Application.Properties.getValue("serverUrl") as String or Null;
        var key = Application.Properties.getValue("apiKey") as String or Null;
        if (url == null || url.length() == 0 || url.find("TON-SOUS-DOMAINE") != null) {
            return "Adresse non réglée";
        }
        if (key == null || key.length() == 0 || key.equals("TA_CLE")) {
            return "Clé non réglée";
        }
        if (url.substring(url.length() - 1, url.length()).equals("/")) {
            url = url.substring(0, url.length() - 1);
        }

        var headers = { "Authorization" => "Bearer " + key };
        var params = null;
        if (isPost) {
            headers["Content-Type"] = Communications.REQUEST_CONTENT_TYPE_JSON;
            params = {};
        }
        var options = {
            :method => isPost ? Communications.HTTP_REQUEST_METHOD_POST
                              : Communications.HTTP_REQUEST_METHOD_GET,
            :headers => headers,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url + path, params, options, callback);
        return null;
    }

    // Message court et lisible pour un code de réponse en échec.
    function errorText(code as Number, data) as String {
        if (code == 401) {
            return "Clé refusée";
        } else if (code == Communications.BLE_CONNECTION_UNAVAILABLE
                || code == Communications.BLE_HOST_TIMEOUT
                || code == Communications.BLE_QUEUE_FULL) {
            return "Téléphone non connecté";
        } else if (code == Communications.NETWORK_REQUEST_TIMED_OUT
                || code == Communications.BLE_SERVER_TIMEOUT) {
            return "Délai dépassé";
        } else if (code == Communications.SECURE_CONNECTION_REQUIRED) {
            return "HTTPS requis";
        } else if (code == Communications.NETWORK_RESPONSE_TOO_LARGE
                || code == Communications.INVALID_HTTP_BODY_IN_NETWORK_RESPONSE) {
            return "Réponse illisible";
        }
        if (data instanceof Dictionary && data["error"] != null) {
            var msg = data["error"].toString();
            return msg.length() > 40 ? msg.substring(0, 40) : msg;
        }
        return "Erreur " + code;
    }
}
