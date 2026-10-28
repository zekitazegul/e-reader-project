import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app_language.dart';

const updateRepository = 'zekitazegul/e-reader-project';

class AppRelease {
  const AppRelease(this.version, this.apk, {this.notes = ''});
  final String version;
  final Uri apk;
  final String notes;

  bool isNewerThan(String installed, int build) {
    final releaseBuild = int.tryParse(version.split('+').skip(1).join());
    if (releaseBuild != null) return releaseBuild > build;
    List<int> parts(String value) => value
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final latest = parts(version);
    final current = parts(installed);
    for (var i = 0; i < 3; i++) {
      final a = i < latest.length ? latest[i] : 0;
      final b = i < current.length ? current[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }
}

Future<AppRelease?> latestAppRelease(http.Client client) async {
  final response = await client
      .get(
        Uri.https('api.github.com', '/repos/$updateRepository/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      )
      .timeout(const Duration(seconds: 20));
  if (response.statusCode == 404) return null;
  if (response.statusCode != 200) {
    throw const FormatException('Update service unavailable');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  if (data['draft'] == true || data['prerelease'] == true) return null;
  final version = data['tag_name'];
  if (version is! String ||
      !RegExp(r'^v?\d+\.\d+\.\d+(?:\+\d+)?$').hasMatch(version)) {
    throw const FormatException('Invalid release version');
  }
  final assets = (data['assets'] as List)
      .whereType<Map<String, dynamic>>()
      .toList();
  // Prefer the universal installer: do not accidentally serve an x86/ABI split.
  const preferred = [
    'E-Reader-Installer.apk',
    'E-Reader.apk',
    'app-release.apk',
    'app-debug.apk',
  ];
  for (final name in preferred) {
    for (final asset in assets.where(
      (asset) => asset['name'] == name && asset['state'] == 'uploaded',
    )) {
      final uri = Uri.tryParse(asset['browser_download_url'] as String? ?? '');
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'github.com' &&
          uri.path.startsWith('/$updateRepository/releases/download/') &&
          uri.path.toLowerCase().endsWith('.apk')) {
        final notes = data['body'] is String
            ? (data['body'] as String).trim()
            : '';
        return AppRelease(
          version,
          uri,
          notes: notes.length > 2000 ? notes.substring(0, 2000) : notes,
        );
      }
    }
  }
  throw const FormatException('No Android installer in release');
}

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    this.client,
    this.initialRelease,
    this.autoDownload = false,
  });
  final http.Client? client;
  final AppRelease? initialRelease;
  final bool autoDownload;
  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  static const channel = MethodChannel('e_reader/chrome');
  late final client = widget.client ?? http.Client();
  String status = 'Yeni sürüm kontrol ediliyor…';
  bool busy = true;
  AppRelease? available;
  @override
  void initState() {
    super.initState();
    if (widget.initialRelease != null && widget.autoDownload) {
      available = widget.initialRelease;
      download();
    } else {
      check();
    }
  }

  @override
  void dispose() {
    if (widget.client == null) client.close();
    super.dispose();
  }

  Future<void> check() async {
    try {
      final installed = await channel.invokeMapMethod<String, dynamic>(
        'appVersion',
      );
      final release = await latestAppRelease(client);
      if (!mounted) return;
      if (release == null) {
        status = 'Henüz indirilebilir yeni sürüm yayımlanmadı.';
      } else if (!release.isNewerThan(
        installed?['version'] as String? ?? '0.0.0',
        installed?['build'] as int? ?? 0,
      )) {
        status = 'En güncel sürümü kullanıyorsun.';
      } else {
        available = release;
        status = 'Yeni sürüm hazır: ${release.version}';
      }
    } catch (_) {
      if (!mounted) return;
      status = 'Güncelleme kontrol edilemedi. İnternet bağlantını kontrol edip tekrar dene.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> download() async {
    final release = available;
    if (release == null) return;
    setState(() {
      busy = true;
      status = 'İndirme başlatılıyor…';
    });
    try {
      await channel.invokeMethod<void>('downloadUpdate', {
        'url': release.apk.toString(),
        'version': release.version,
      });
      if (!mounted) return;
      setState(() {
        available = null;
        status = 'Güncelleme indiriliyor. İndirme tamamlandığında bildirime dokunarak kurulumu başlatabilirsin.';
      });
    } catch (_) {
      if (mounted) {
        setState(() => status = 'İndirme başlatılamadı. Tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const AppText('Uygulamayı güncelle'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          AppText(status),
          if (available?.notes.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(available!.notes),
          ],
        ],
      ),
    ),
    actions: [
      if (available != null)
        FilledButton.icon(
          onPressed: busy ? null : download,
          icon: const Icon(Icons.download),
          label: const AppText('Güncelle'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).closeButtonLabel),
      ),
    ],
  );
}

/// A passive notice: checks never download or interrupt offline reading.
class AppUpdateBanner extends StatefulWidget {
  const AppUpdateBanner({super.key, this.client, this.onAvailable});
  final http.Client? client;
  final ValueChanged<AppRelease?>? onAvailable;
  @override
  State<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends State<AppUpdateBanner>
    with WidgetsBindingObserver {
  static const channel = MethodChannel('e_reader/chrome');
  late final client = widget.client ?? http.Client();
  AppRelease? available;
  DateTime? checkedAt;
  bool checking = false;
  bool get supported =>
      widget.client != null ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (supported) check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        supported &&
        (checkedAt == null ||
            DateTime.now().difference(checkedAt!) >
                const Duration(minutes: 15))) {
      check();
    }
  }

  Future<void> check() async {
    if (checking) return;
    checking = true;
    checkedAt = DateTime.now();
    try {
      final installed = await channel.invokeMapMethod<String, dynamic>(
        'appVersion',
      );
      final release = await latestAppRelease(client);
      if (!mounted) return;
      final newer =
          release?.isNewerThan(
            installed?['version'] as String? ?? '0.0.0',
            installed?['build'] as int? ?? 0,
          ) ??
          false;
      setState(() => available = newer ? release : null);
      widget.onAvailable?.call(available);
    } catch (_) {
      // No error prompt during startup or offline reading.
    } finally {
      checking = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.client == null) client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final release = available;
    if (release == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Card(
        margin: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.system_update),
              const SizedBox(width: 12),
              Expanded(child: AppText('Yeni sürüm hazır: ${release.version}')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AppUpdateDialog(
                    initialRelease: release,
                    autoDownload: true,
                  ),
                ),
                child: const AppText('Güncelle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
