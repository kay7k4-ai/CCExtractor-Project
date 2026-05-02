import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const CCExtractorApp());
}

// ─── GLOBAL STATE ──────────────────────────────────────────────────────────────
class AppState {
  static Map<String, dynamic>? lastSingleResult;
  static List<Map<String, dynamic>> batchResults = [];
  static int? lastBatchPassed;
  static int? lastBatchFailed;
  static int? lastBatchTotal;

  static void resetAll() {
    lastSingleResult = null;
    batchResults = [];
    lastBatchPassed = null;
    lastBatchFailed = null;
    lastBatchTotal = null;
  }
}

// ─── THEME ─────────────────────────────────────────────────────────────────────
class AppColors {
  static const bg = Color(0xFF080C10);
  static const surface = Color(0xFF0E1318);
  static const surfaceHigh = Color(0xFF141A22);
  static const border = Color(0xFF1E2730);
  static const borderHigh = Color(0xFF2A3540);
  static const accent = Color(0xFF00D4FF);
  static const accentDim = Color(0xFF0099BB);
  static const green = Color(0xFF00E676);
  static const red = Color(0xFFFF3D57);
  static const textPrimary = Color(0xFFE8EDF2);
  static const textSecondary = Color(0xFF6B7A8A);
  static const textDim = Color(0xFF3A4550);
}

class CCExtractorApp extends StatelessWidget {
  const CCExtractorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CCExtractor · Regression Suite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

// ─── DASHBOARD ─────────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  void _resetEverything() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Reset Everything?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: const Text(
          'This will clear all test results, file selections, and history from the current session.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red.withOpacity(0.15),
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              AppState.resetAll();
              Navigator.pop(ctx);
              setState(() {}); // trigger rebuild
              ScaffoldMessenger.of(context).showSnackBar(
                _snackBar('Session cleared. Fresh start!', AppColors.accent),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          // ── Sidebar ──
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo area
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.accent.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.closed_caption,
                                color: AppColors.accent, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CCExtractor',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3)),
                              Text('Regression Suite',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Nav items
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      _SidebarItem(
                        icon: Icons.play_arrow_rounded,
                        label: 'Single Test',
                        sublabel: 'Run one file',
                        selected: _selectedIndex == 0,
                        onTap: () => setState(() => _selectedIndex = 0),
                      ),
                      const SizedBox(height: 2),
                      _SidebarItem(
                        icon: Icons.layers_rounded,
                        label: 'Batch Test',
                        sublabel: 'Run multiple files',
                        selected: _selectedIndex == 1,
                        onTap: () => setState(() => _selectedIndex = 1),
                      ),
                      const SizedBox(height: 2),
                      _SidebarItem(
                        icon: Icons.table_rows_rounded,
                        label: 'Results',
                        sublabel: 'History & lookup',
                        selected: _selectedIndex == 2,
                        onTap: () => setState(() => _selectedIndex = 2),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Status indicator
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.green.withOpacity(0.5),
                                  blurRadius: 6)
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Backend',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10)),
                            Text('localhost:8000',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Reset button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _resetEverything,
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: const Text('Reset Session',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: BorderSide(
                            color: AppColors.red.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main content ──
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                SingleTestPage(),
                BatchTestPage(),
                ResultsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.accent.withOpacity(0.25)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accent.withOpacity(0.15)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon,
                  size: 15,
                  color: selected
                      ? AppColors.accent
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal)),
                Text(sublabel,
                    style: const TextStyle(
                        color: AppColors.textDim, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SINGLE TEST PAGE ──────────────────────────────────────────────────────────
class SingleTestPage extends StatefulWidget {
  const SingleTestPage({super.key});

  @override
  State<SingleTestPage> createState() => _SingleTestPageState();
}

class _SingleTestPageState extends State<SingleTestPage> {
  PlatformFile? _file;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = AppState.lastSingleResult;
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform
        .pickFiles(withData: true, allowMultiple: false);
    if (r != null) {
      setState(() {
        _file = r.files.first;
        _result = null;
        _error = null;
      });
    }
  }

  void _clear() {
    setState(() {
      _file = null;
      _result = null;
      _error = null;
      AppState.lastSingleResult = null;
    });
  }

  Future<void> _run() async {
    if (_file == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('https://ccextractor-backend.onrender.com//run-test'));
      req.files.add(http.MultipartFile.fromBytes('file', _file!.bytes!,
          filename: _file!.name));
      final res = await req.send();
      final body = await res.stream.bytesToString();
      final data = jsonDecode(body);
      AppState.lastSingleResult = data;
      setState(() {
        _result = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      title: 'Single Test',
      subtitle: 'Upload one file, run CCExtractor, compare output',
      action: _result != null || _file != null
          ? _ClearButton(onTap: _clear)
          : null,
      child: Column(
        children: [
          // Upload zone
          _UploadZone(
            file: _file,
            onTap: _pick,
            onClear: _file != null ? () => setState(() => _file = null) : null,
          ),
          const SizedBox(height: 16),

          // Run button
          SizedBox(
            width: double.infinity,
            child: _PrimaryButton(
              label: 'Run Test',
              icon: Icons.play_arrow_rounded,
              loading: _loading,
              enabled: _file != null,
              onTap: _run,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _error!),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _SingleResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

// ─── BATCH TEST PAGE ───────────────────────────────────────────────────────────
class BatchTestPage extends StatefulWidget {
  const BatchTestPage({super.key});

  @override
  State<BatchTestPage> createState() => _BatchTestPageState();
}

class _BatchTestPageState extends State<BatchTestPage> {
  List<PlatformFile> _files = [];
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (AppState.batchResults.isNotEmpty) {
      _result = {
        'total': AppState.lastBatchTotal,
        'passed': AppState.lastBatchPassed,
        'failed': AppState.lastBatchFailed,
        'details': AppState.batchResults,
      };
    }
  }

  Future<void> _addFiles() async {
    final r = await FilePicker.platform
        .pickFiles(withData: true, allowMultiple: true);
    if (r != null) {
      final existing = _files.map((f) => f.name).toSet();
      final newOnes = r.files.where((f) => !existing.contains(f.name));
      setState(() => _files = [..._files, ...newOnes]);
    }
  }

  void _clearAll() {
    setState(() {
      _files = [];
      _result = null;
      _error = null;
      AppState.batchResults = [];
      AppState.lastBatchTotal = null;
      AppState.lastBatchPassed = null;
      AppState.lastBatchFailed = null;
    });
  }

  Future<void> _run() async {
    if (_files.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('https://ccextractor-backend.onrender.com//run-batch'));
      for (final f in _files) {
        req.files.add(http.MultipartFile.fromBytes('files', f.bytes!,
            filename: f.name));
      }
      final res = await req.send();
      final body = await res.stream.bytesToString();
      final data = jsonDecode(body);
      AppState.batchResults =
          List<Map<String, dynamic>>.from(data['details'] ?? []);
      AppState.lastBatchTotal = data['total'];
      AppState.lastBatchPassed = data['passed'];
      AppState.lastBatchFailed = data['failed'];
      setState(() {
        _result = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      title: 'Batch Test',
      subtitle: 'Upload multiple files, run all, get summary',
      action: (_files.isNotEmpty || _result != null)
          ? _ClearButton(onTap: _clearAll)
          : null,
      child: Column(
        children: [
          // File list
          if (_files.isNotEmpty) ...[
            _FileListCard(
              files: _files,
              onRemove: (i) =>
                  setState(() => _files = List.from(_files)..removeAt(i)),
            ),
            const SizedBox(height: 12),
          ],

          // Add files + run row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addFiles,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(_files.isEmpty ? 'Select Files' : 'Add More'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              if (_files.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _PrimaryButton(
                    label: 'Run Batch (${_files.length})',
                    icon: Icons.layers_rounded,
                    loading: _loading,
                    enabled: _files.isNotEmpty,
                    onTap: _run,
                  ),
                ),
              ],
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: _error!),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _BatchResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

// ─── RESULTS PAGE ──────────────────────────────────────────────────────────────
class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  List<dynamic> _results = [];
  bool _loading = false;
  String? _error;
  final _searchCtrl = TextEditingController();
  final _lookupCtrl = TextEditingController();
  Map<String, dynamic>? _lookupResult;
  bool _lookupLoading = false;
  String? _lookupError;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse('https://ccextractor-backend.onrender.com//results'));
      final data = jsonDecode(res.body);
      setState(() {
        _results = data is List ? data : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _clearResults() {
    setState(() {
      _results = [];
      _lookupResult = null;
      _lookupError = null;
      _lookupCtrl.clear();
      _searchCtrl.clear();
    });
  }

  Future<void> _lookup() async {
    final id = _lookupCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _lookupLoading = true;
      _lookupResult = null;
      _lookupError = null;
    });
    try {
      final res =
          await http.get(Uri.parse('https://ccextractor-backend.onrender.com//results/$id'));
      final data = jsonDecode(res.body);
      if (data['error'] != null) {
        setState(() {
          _lookupError = 'No result found for this ID';
          _lookupLoading = false;
        });
      } else {
        setState(() {
          _lookupResult = data;
          _lookupLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _lookupError = e.toString();
        _lookupLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _results
        .where((r) => (r['id'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_searchCtrl.text.toLowerCase()))
        .toList();

    return _PageShell(
      title: 'Results',
      subtitle: 'History & ID lookup',
      action: Row(
        children: [
          if (_results.isNotEmpty)
            _ClearButton(onTap: _clearResults, label: 'Clear View'),
          const SizedBox(width: 8),
          _IconAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onTap: _fetch),
        ],
      ),
      child: Column(
        children: [
          // Lookup card
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Lookup by File ID'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StyledTextField(
                        controller: _lookupCtrl,
                        hint: 'Paste file ID...',
                        onSubmit: (_) => _lookup(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PrimaryButton(
                      label: 'Search',
                      icon: Icons.search_rounded,
                      loading: _lookupLoading,
                      enabled: true,
                      onTap: _lookup,
                      compact: true,
                    ),
                  ],
                ),
                if (_lookupError != null) ...[
                  const SizedBox(height: 8),
                  Text(_lookupError!,
                      style: const TextStyle(
                          color: AppColors.red, fontSize: 12)),
                ],
                if (_lookupResult != null) ...[
                  const SizedBox(height: 12),
                  _LookupResultTile(result: _lookupResult!),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // History table
          _GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: _Label('History'),
                      ),
                      SizedBox(
                        width: 200,
                        child: _StyledTextField(
                          controller: _searchCtrl,
                          hint: 'Filter by ID...',
                          onSubmit: (_) => setState(() {}),
                          onChanged: (_) => setState(() {}),
                          prefix: const Icon(Icons.search_rounded,
                              size: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _ErrorBanner(message: _error!),
                  )
                else if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No results yet.',
                        style: TextStyle(
                            color: AppColors.textDim, fontSize: 13)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (ctx, i) {
                      final row = filtered[i];
                      final id = row['id']?.toString() ?? '-';
                      final pass = row['status'] == 'PASS';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            _StatusDot(pass: pass),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(id,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontFamily: 'monospace'),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            _StatusChip(pass: pass),
                            const SizedBox(width: 8),
                            _CopyIconBtn(text: id),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PAGE SHELL ────────────────────────────────────────────────────────────────
class _PageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  final Widget child;

  const _PageShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 32,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

// ─── UPLOAD ZONE ───────────────────────────────────────────────────────────────
class _UploadZone extends StatelessWidget {
  final PlatformFile? file;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _UploadZone(
      {required this.file, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: hasFile
              ? AppColors.green.withOpacity(0.04)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile
                ? AppColors.green.withOpacity(0.3)
                : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasFile
                    ? AppColors.green.withOpacity(0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: hasFile
                        ? AppColors.green.withOpacity(0.3)
                        : AppColors.border),
              ),
              child: Icon(
                hasFile
                    ? Icons.check_circle_outline_rounded
                    : Icons.upload_file_rounded,
                color:
                    hasFile ? AppColors.green : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasFile ? file!.name : 'Drop file here or click to browse',
              style: TextStyle(
                color: hasFile
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight:
                    hasFile ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            if (!hasFile) ...[
              const SizedBox(height: 4),
              const Text('.mp4  .mkv  .ts  .mpg  .srt',
                  style: TextStyle(
                      color: AppColors.textDim, fontSize: 11)),
            ],
            if (hasFile && onClear != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  onClear!();
                },
                child: const Text('✕  Remove file',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── FILE LIST CARD ────────────────────────────────────────────────────────────
class _FileListCard extends StatelessWidget {
  final List<PlatformFile> files;
  final Function(int) onRemove;

  const _FileListCard({required this.files, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                _Label('${files.length} file${files.length > 1 ? 's' : ''} selected'),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: files.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (ctx, i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(files[i].name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      GestureDetector(
                        onTap: () => onRemove(i),
                        child: const Icon(Icons.close_rounded,
                            size: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SINGLE RESULT CARD ────────────────────────────────────────────────────────
class _SingleResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _SingleResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final pass = result['status'] == 'PASS';
    final res = result['result'] as Map<String, dynamic>? ?? {};
    final id = result['file_id']?.toString() ?? '-';

    return _GlassCard(
      borderColor: pass
          ? AppColors.green.withOpacity(0.25)
          : AppColors.red.withOpacity(0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusDot(pass: pass),
              const SizedBox(width: 8),
              Text(pass ? 'Test Passed' : 'Test Failed',
                  style: TextStyle(
                      color: pass ? AppColors.green : AppColors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              _StatusChip(pass: pass),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border),
          const SizedBox(height: 10),
          _DetailRow(
            label: 'File ID',
            value: id,
            mono: true,
            trailing: _CopyIconBtn(text: id),
          ),
          _DetailRow(
              label: 'Missing Lines',
              value: res['missing_lines']?.toString() ?? '[]'),
          _DetailRow(
              label: 'Extra Lines',
              value: res['extra_lines']?.toString() ?? '[]'),
        ],
      ),
    );
  }
}

// ─── BATCH RESULT CARD ─────────────────────────────────────────────────────────
class _BatchResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _BatchResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final total = result['total'] ?? 0;
    final passed = result['passed'] ?? 0;
    final failed = result['failed'] ?? 0;
    final details = result['details'] as List? ?? [];

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Batch Summary'),
          const SizedBox(height: 14),
          Row(
            children: [
              _MetricTile(label: 'Total', value: '$total',
                  color: AppColors.textSecondary),
              const SizedBox(width: 10),
              _MetricTile(label: 'Passed', value: '$passed',
                  color: AppColors.green),
              const SizedBox(width: 10),
              _MetricTile(label: 'Failed', value: '$failed',
                  color: AppColors.red),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 10),
          const _Label('Per File'),
          const SizedBox(height: 10),
          ...details.map((d) {
            final id = d['file_id']?.toString() ?? '-';
            final pass = d['status'] == 'PASS';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _StatusDot(pass: pass),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(id,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis),
                  ),
                  _StatusChip(pass: pass),
                  const SizedBox(width: 6),
                  _CopyIconBtn(text: id),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── LOOKUP RESULT TILE ────────────────────────────────────────────────────────
class _LookupResultTile extends StatelessWidget {
  final Map<String, dynamic> result;
  const _LookupResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final pass = result['status'] == 'PASS';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: pass
                ? AppColors.green.withOpacity(0.3)
                : AppColors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatusDot(pass: pass),
              const SizedBox(width: 8),
              Text(result['status'] ?? '',
                  style: TextStyle(
                      color: pass ? AppColors.green : AppColors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const Spacer(),
              _CopyIconBtn(text: result['id']?.toString() ?? ''),
            ],
          ),
          const SizedBox(height: 10),
          _DetailRow(
              label: 'ID', value: result['id']?.toString() ?? '-', mono: true),
          _DetailRow(
              label: 'Missing', value: result['missing']?.toString() ?? '[]'),
          _DetailRow(
              label: 'Extra', value: result['extra']?.toString() ?? '[]'),
        ],
      ),
    );
  }
}

// ─── SMALL REUSABLE WIDGETS ────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;

  const _GlassCard({required this.child, this.padding, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;
  final bool compact;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: enabled && !loading ? onTap : null,
      icon: loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.black))
          : Icon(icon, size: 16),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textDim,
        padding: EdgeInsets.symmetric(
            vertical: compact ? 12 : 14, horizontal: compact ? 16 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _ClearButton({required this.onTap, this.label = 'Clear'});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.delete_outline_rounded, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.red,
        side: BorderSide(color: AppColors.red.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Function(String)? onSubmit;
  final Function(String)? onChanged;
  final Widget? prefix;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    this.onSubmit,
    this.onChanged,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmit,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
        prefixIcon: prefix != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: prefix)
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent)),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool pass;
  const _StatusDot({required this.pass});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: pass ? AppColors.green : AppColors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: (pass ? AppColors.green : AppColors.red)
                  .withOpacity(0.5),
              blurRadius: 5)
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool pass;
  const _StatusChip({required this.pass});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (pass ? AppColors.green : AppColors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color:
                (pass ? AppColors.green : AppColors.red).withOpacity(0.3)),
      ),
      child: Text(
        pass ? 'PASS' : 'FAIL',
        style: TextStyle(
            color: pass ? AppColors.green : AppColors.red,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _CopyIconBtn extends StatelessWidget {
  final String text;
  const _CopyIconBtn({required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context)
            .showSnackBar(_snackBar('Copied!', AppColors.accent));
      },
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.copy_rounded,
            size: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final Widget? trailing;

  const _DetailRow(
      {required this.label,
      required this.value,
      this.mono = false,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontFamily: mono ? 'monospace' : null)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5));
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.red, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style:
                    const TextStyle(color: AppColors.red, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

SnackBar _snackBar(String msg, Color color) => SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w600)),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    );