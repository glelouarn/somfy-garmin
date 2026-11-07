import Toybox.Graphics;
import Toybox.Lang;

// Libellés et couleurs partagés entre l'aperçu et la vue complète.
(:glance)
module Labels {

    function text(status as String or Null) as String {
        if (status == null) {
            return "Inconnu";
        } else if (status.equals("armed")) {
            return "Armée";
        } else if (status.equals("partial")) {
            return "Partielle";
        } else if (status.equals("disarmed")) {
            return "Désarmée";
        }
        return status;
    }

    function color(status as String or Null) as Number {
        if (status == null) {
            return Graphics.COLOR_LT_GRAY;
        } else if (status.equals("armed")) {
            return Graphics.COLOR_RED;
        } else if (status.equals("partial")) {
            return Graphics.COLOR_ORANGE;
        } else if (status.equals("disarmed")) {
            return Graphics.COLOR_GREEN;
        }
        return Graphics.COLOR_LT_GRAY;
    }
}
