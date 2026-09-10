using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Attention;

class PullUpCounterApp extends Application.AppBase {
    var mainView;
    var restTimer;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {}

    function onStop(state) {
        if (restTimer != null) {
            restTimer.stop();
        }
    }

    function getInitialView() {
        mainView = new PullUpCounterView();

        restTimer = new Timer.Timer();
        restTimer.start(method(:onTimerTick), 1000, true);

        return [mainView, new PullUpCounterDelegate(mainView)];
    }

    function onTimerTick() as Void {
        var boundaryReached = mainView.tick();

        if (
            boundaryReached &&
            mainView.vibrationEnabled
        ) {
            vibrate();
        }
    }

    function vibrate() as Void {
        var vibration = [new Attention.VibeProfile(100, 250)];

        Attention.vibrate(vibration);
    }
}

function getApp() as PullUpCounterApp {
    return Application.getApp() as PullUpCounterApp;
}
