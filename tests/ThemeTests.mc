using Toybox.Test;
using Toybox.Lang;

(:test)
function themeBackupCompatibility(logger) {
    var view = timerTestView();
    Test.assert(AppData.preferences(view.workoutStore.storage)["theme"].equals("cyan"));
    view.workoutStore.storage.put("theme", "orange");
    view.reloadSettings(); Test.assert(AppTheme.color() == 0xff9500);
    var backup = new WorkoutBackup(view.workoutStore);
    var header = backup.next() as Lang.Dictionary;
    Test.assert((header["settings"] as Lang.Dictionary)["theme"].equals("orange"));
    var backend = new MemoryWorkoutStorage();
    var restore = new WorkoutRestore(backend);
    restore.accept(header); restore.accept(backup.next() as Lang.Dictionary); restore.commit();
    Test.assert(AppData.preferences(new SelectedWorkoutStorage(backend, null))["theme"].equals("orange"));
    (header["settings"] as Lang.Dictionary).remove("theme");
    backend = new MemoryWorkoutStorage(); restore = new WorkoutRestore(backend);
    backup = new WorkoutBackup(view.workoutStore); backup.next();
    restore.accept(header); restore.accept(backup.next() as Lang.Dictionary); restore.commit();
    Test.assert(AppData.preferences(new SelectedWorkoutStorage(backend, null))["theme"].equals("cyan"));
    Test.assert(AppTheme.normalize("unknown").equals("cyan"));
    AppTheme.selected = "red"; Test.assert(AppTheme.color() == 0xff4545);
    AppTheme.selected = "cyan";
    return true;
}
