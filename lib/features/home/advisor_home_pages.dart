part of 'advisor_home_screen.dart';

  Widget _studyPlannerPage() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
    children: [
      Row(children: [
        IconButton(onPressed: () => setState(() => _tab = 'خانه'),
          icon: const Icon(Icons.arrow_forward_rounded), tooltip: 'بازگشت به خانه'),
        const SizedBox(width: 6),
        const Expanded(child: Text('برنامهٔ درسی من',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
      ]),
      const SizedBox(height: 8),
      const Text('کارهای درسی را ثبت کن و پس از انجام، تیک بزن.',
        style: TextStyle(color: Colors.black54, height: 1.7)),
      const SizedBox(height: 18),
      _focusTimerCard(),
      const SizedBox(height: 16),
      _studyProgressSection(),
      const SizedBox(height: 12),
      _masteryGuidanceSection(),
      const SizedBox(height: 12),
      _weeklyProgressReport(),
      const SizedBox(height: 12),
      _reviewPracticeSection(),
      const SizedBox(height: 12),
      _adaptivePlanCard(),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _openStepTutor,
        icon: const Icon(Icons.school_outlined), label: const Text('مربی آموزشی قدم‌به‌قدم')),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2EAE6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!_localDataLoaded)
            const Padding(padding: EdgeInsets.only(bottom: 10), child: LinearProgressIndicator()),
          TextField(controller: _newTaskController,
            enabled: _localDataLoaded,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addStudyTask(),
            decoration: InputDecoration(
              labelText: 'کار یا درس بعدی',
              hintText: 'مثلاً: مرور فصل دوم علوم',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _localDataLoaded ? _addStudyTask : null,
            icon: const Icon(Icons.add_task_rounded), label: const Text('افزودن به برنامه')),
        ]),
      ),
      const SizedBox(height: 18),
      Builder(builder: (context) {
        final today = DateTime.now();
        final overdue = _studyTasks.asMap().entries.where((entry) {
          if (_completedTasks.contains(entry.key)) return false;
          final raw = _taskDueDates[entry.value];
          if (raw == null) return false;
          final date = DateTime.parse(raw);
          return DateTime(date.year, date.month, date.day).isBefore(DateTime(today.year, today.month, today.day));
        }).length;
        final dueToday = _studyTasks.asMap().entries.where((entry) {
          if (_completedTasks.contains(entry.key)) return false;
          final raw = _taskDueDates[entry.value];
          if (raw == null) return false;
          final date = DateTime.parse(raw);
          return date.year == today.year && date.month == today.month && date.day == today.day;
        }).length;
        return Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE3F2ED), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Text('موعد امروز: $dueToday', style: const TextStyle(fontWeight: FontWeight.w800))),
            Expanded(child: Text('عقب‌افتاده: $overdue', style: TextStyle(fontWeight: FontWeight.w800, color: overdue > 0 ? Colors.red.shade700 : const Color(0xFF287D72)))),
          ]));
      }),
      const SizedBox(height: 14),
      _weeklyScheduleSection(),
      const SizedBox(height: 14),
      Row(children: [
        const Expanded(child: Text('همهٔ کارهای درسی',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        Text('${_completedTasks.length} از ${_studyTasks.length} انجام‌شده',
          style: const TextStyle(color: Color(0xFF287D72), fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 10),
      if (_studyTasks.isEmpty)
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFFEAF3F0), borderRadius: BorderRadius.circular(18)),
          child: const Column(children: [
            Icon(Icons.event_note_outlined, size: 34, color: Color(0xFF287D72)),
            SizedBox(height: 8),
            Text('هنوز کاری ثبت نشده است', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('اولین کار درسی خود را در کادر بالا بنویس.',
              textAlign: TextAlign.center, style: TextStyle(height: 1.6)),
          ]),
        )
      else
        ..._studyTasks.asMap().entries.map((entry) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: _completedTasks.contains(entry.key),
            onChanged: (checked) {
              setState(() {
                if (checked == true) { _completedTasks.add(entry.key); }
                else { _completedTasks.remove(entry.key); }
              });
              _saveData();
            },
            title: Text(entry.value),
            subtitle: Text(_taskScheduleLabel(entry.value),
              style: TextStyle(height: 1.5, color: _taskDueDates[entry.value] != null && !_completedTasks.contains(entry.key) && DateTime.parse(_taskDueDates[entry.value]!).isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) ? Colors.red.shade700 : Colors.black54)),
            controlAffinity: ListTileControlAffinity.leading,
            secondary: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'تنظیم موعد', icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () => _setTaskDueDate(entry.value)),
              IconButton(
              tooltip: 'حذف کار',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                setState(() {
                  final updatedCompleted = _completedTasks
                    .where((index) => index != entry.key)
                    .map((index) => index > entry.key ? index - 1 : index)
                    .toSet();
                  _studyTasks.removeAt(entry.key);
                  _completedTasks
                    ..clear()
                    ..addAll(updatedCompleted);
                });
                _taskDueDates.remove(entry.value);
                _saveData();
              }
              ),
            ]),
          ),
        )),
      const SizedBox(height: 12),
      const Text('کارها، وضعیت انجام و یادداشت‌ها روی همین دستگاه ذخیره می‌شوند. برای انتقال به گوشی دیگر، همگام‌سازی ابری در نسخهٔ بعدی لازم است.',
        style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.7)),
    ],
  );
