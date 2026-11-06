part of 'advisor_home_screen.dart';

  void _toggleFocusTimer() {
    if (_focusRunning) {
      _focusTimer?.cancel();
      setState(() => _focusRunning = false);
      return;
    }
    if (_focusSecondsRemaining <= 0) {
      setState(() => _focusSecondsRemaining = 25 * 60);
    }
    setState(() => _focusRunning = true);
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_focusSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _focusSecondsRemaining = 0;
          _focusRunning = false;
        });
      } else {
        setState(() => _focusSecondsRemaining--);
      }
    });
  }

  void _resetFocusTimer() {
    _focusTimer?.cancel();
    setState(() {
      _focusRunning = false;
      _focusSecondsRemaining = 25 * 60;
    });
  }
