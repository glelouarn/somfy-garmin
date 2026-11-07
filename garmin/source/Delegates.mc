import Toybox.Lang;
import Toybox.WatchUi;

// Gestion des entrées SANS BehaviorDelegate : avec un BehaviorDelegate, la montre
// convertit un toucher en « START » (onSelect), qui applique la sélection courante
// au lieu de l'objet touché. Ici, boutons et tactile restent séparés :
//   UP / DOWN : changer la sélection   START : appliquer la sélection
//   toucher une icône : appliquer CETTE icône   UP maintenu (MENU) : actualiser
class MainDelegate extends WatchUi.InputDelegate {

    private var _view as MainView;

    function initialize(view as MainView) {
        InputDelegate.initialize();
        _view = view;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP) {
            _view.move(-1);
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            _view.move(1);
            return true;
        } else if (key == WatchUi.KEY_ENTER) {
            _view.activate();
            return true;
        } else if (key == WatchUi.KEY_MENU) {
            _view.refresh();
            return true;
        }
        return false;   // BACK et autres : comportement normal de la montre
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var xy = evt.getCoordinates();
        var i = _view.indexAt(xy[0], xy[1]);
        if (i >= 0) {
            _view.choose(i);
        } else if (_view.isTitleArea(xy[1])) {
            _view.refresh();   // toucher le titre : actualiser (utile sur Venu, sans bouton UP)
        }
        return true;
    }

    // Balayage haut / bas : changer la sélection (montres sans boutons UP / DOWN).
    // Gauche / droite : laissés au système (droite = retour).
    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            _view.move(1);
            return true;
        } else if (dir == WatchUi.SWIPE_DOWN) {
            _view.move(-1);
            return true;
        }
        return false;
    }
}
