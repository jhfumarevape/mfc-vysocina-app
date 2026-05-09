import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';

import '../core/theme.dart';
import '../services/update_checker.dart';
import 'feed_screen.dart';
import 'calendar_screen.dart';
import 'chat_list_screen.dart';
import 'tactics_screen.dart';
import 'rules_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  late final UpdateChecker _updater;

  @override
  void initState() {
    super.initState();
    _updater = UpdateChecker();
    // Check for updates on app start (silently, no UI block)
    Future.delayed(const Duration(seconds: 2), () => _updater.check());
  }

  Future<void> _showUpdateDialog() async {
    final info = _updater.info;
    if (info == null) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nová verze dostupná'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verze ${info.latestVersion}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (info.releaseNotes.isNotEmpty) Text(info.releaseNotes),
            const SizedBox(height: 12),
            const Text('Stáhnout a nainstalovat?', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Později')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aktualizovat')),
        ],
      ),
    );
    if (go == true) await _doDownloadAndInstall();
  }

  Future<void> _doDownloadAndInstall() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: _updater,
        child: Consumer<UpdateChecker>(
          builder: (_, u, __) => AlertDialog(
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Stahuji aktualizaci...'),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: u.downloadProgress, color: AppTheme.primary),
              const SizedBox(height: 8),
              Text('${(u.downloadProgress * 100).toInt()} %'),
            ]),
          ),
        ),
      ),
    );
    final file = await _updater.downloadApk();
    if (mounted) Navigator.of(context).pop();
    if (file != null) {
      await OpenFilex.open(file.path);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stažení selhalo')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _updater,
      child: Consumer<UpdateChecker>(
        builder: (_, u, __) => Scaffold(
          body: Column(
            children: [
              if (u.hasUpdate)
                Material(
                  color: AppTheme.primary,
                  child: SafeArea(
                    bottom: false,
                    child: InkWell(
                      onTap: _showUpdateDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(children: [
                          const Icon(Icons.system_update, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Nová verze ${u.info!.latestVersion} dostupná — klikni pro aktualizaci', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                          const Icon(Icons.chevron_right, color: Colors.white),
                        ]),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: const [
                    FeedScreen(),
                    CalendarScreen(),
                    ChatListScreen(),
                    TacticsScreen(),
                    RulesScreen(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Domů'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Kalendář'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat'),
              BottomNavigationBarItem(icon: Icon(Icons.play_circle_outline), activeIcon: Icon(Icons.play_circle), label: 'Taktiky'),
              BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: 'Pravidla'),
            ],
          ),
        ),
      ),
    );
  }
}
