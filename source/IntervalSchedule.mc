// Keep the original cadence even after delayed ticks or reopening the app.
module IntervalSchedule {
    function nextEnd(endTime, duration, now) {
        if (now < endTime) { return endTime; }
        return endTime + (((now - endTime) / duration).toNumber() + 1) * duration;
    }
}
