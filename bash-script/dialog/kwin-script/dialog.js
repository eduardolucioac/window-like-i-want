workspace.windowAdded.connect(function (windowNow) {
    if (windowNow.pid == $DIALOG_PID) {
        let originalOpacity = windowNow.opacity;

        // Hide the window before applying any transformations for better
        // user visual experience.
        windowNow.opacity = 0;

        let restoreOpacityQTimer = new QTimer();
        restoreOpacityQTimer.timeout.connect(() => {
            windowNow.opacity = originalOpacity;
            restoreOpacityQTimer.stop();
        });
        restoreOpacityQTimer.start(350);

        windowNow.noBorder = true;

        // NOTE: Centred, NOT resized. The dialog asks Konsole for the exact
        // number of columns and rows its content needs, so Konsole has already
        // sized the window correctly by the time it gets here. Forcing 40% of
        // the screen on top of that is what used to make the box wrap, and it
        // also taught Konsole the wrong size to use for the user's own
        // windows.
        let currentGeometry = windowNow.frameGeometry;
        let screenGeometry = workspace.screens[0].geometry;

        windowNow.frameGeometry = {
            x:
                screenGeometry.x +
                Math.floor((screenGeometry.width - currentGeometry.width) / 2),
            y:
                screenGeometry.y +
                Math.floor((screenGeometry.height - currentGeometry.height) / 2),
            width: currentGeometry.width,
            height: currentGeometry.height,
        };

    }
});

