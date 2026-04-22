import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class CasioMaxApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new CasioMaxView() ];
    }

}

function getApp() as CasioMaxApp {
    return Application.getApp() as CasioMaxApp;
}
