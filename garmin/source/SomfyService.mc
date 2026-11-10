import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Tâche de fond : relit l'état de l'alarme pour que l'aperçu reste juste,
// même quand l'état a été changé depuis un autre appareil.
(:background)
class SomfyService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        if (SomfyApi.request("/status", false, method(:onResponse)) != null) {
            Background.exit(null);   // passerelle non configurée
        }
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 200 && data instanceof Dictionary && data["status"] != null) {
            var res = { "status" => data["status"], "updated" => Time.now().value() };
            if (data["site"] != null) {
                res["site"] = data["site"].toString();
            }
            Background.exit(res);
        } else {
            Background.exit(null);
        }
    }
}
