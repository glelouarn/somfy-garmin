import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Aperçu : cadenas de l'état actuel sur rond jaune + nom de l'état.
// Affiche le dernier état connu (mis à jour à chaque ouverture de l'app).
(:glance)
class SomfyGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var status = Application.Storage.getValue("status") as String or Null;
        var h = dc.getHeight();
        var r = h * 38 / 100;            // un peu de marge en haut et en bas
        var cx = r + 1;
        var cy = h / 2;

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        if (status != null) {
            dc.setColor(LockIcon.YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r);
            LockIcon.draw(dc, status, cx, cy, r * 2, LockIcon.NAVY, LockIcon.YELLOW);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_GLANCE, "?",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // Texte centré dans la zone libre à droite du rond.
        var left = 2 * r + 2;
        dc.drawText((left + dc.getWidth()) / 2, cy, Graphics.FONT_GLANCE, Labels.text(status),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
