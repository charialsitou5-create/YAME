import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/my_report.dart';
import '../../repositories/incident_repository.dart';
import '../../repositories/user_repository.dart';

String reportCategoryLabel(String code) {
  switch (code) {
    case 'securite':
      return AppStrings.reportCategorySecurity;
    case 'paiement':
      return AppStrings.reportCategoryPayment;
    case 'comportement':
      return AppStrings.reportCategoryBehavior;
    case 'vehicule':
      return AppStrings.reportCategoryVehicle;
    default:
      return AppStrings.reportCategoryOther;
  }
}

String _dateLabel(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// Liste « Mes signalements », avec pastille quand l'équipe a répondu.
///
/// [openIncidentId] : ouvre directement le détail (tap sur la notification
/// push `incident_reply`).
class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({
    super.key,
    required this.uid,
    this.openIncidentId,
    this.userRepository,
    this.incidentRepository,
  });

  final String uid;
  final String? openIncidentId;
  final UserRepository? userRepository;
  final IncidentRepository? incidentRepository;

  @override
  Widget build(BuildContext context) {
    final users = userRepository ?? UserRepository();
    final incidents = incidentRepository ?? IncidentRepository();
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myReportsTitle)),
      body: SafeArea(
        child: StreamBuilder(
          stream: users.watchUser(uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.accent));
            }
            final reports = MyReport.listFromUserData(snapshot.data?.data());
            if (reports.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(AppStrings.myReportsEmpty, textAlign: TextAlign.center),
                ),
              );
            }
            return _ReportsList(
              reports: reports,
              repo: incidents,
              openIncidentId: openIncidentId,
            );
          },
        ),
      ),
    );
  }
}

class _ReportsList extends StatefulWidget {
  const _ReportsList({required this.reports, required this.repo, this.openIncidentId});

  final List<MyReport> reports;
  final IncidentRepository repo;
  final String? openIncidentId;

  @override
  State<_ReportsList> createState() => _ReportsListState();
}

class _ReportsListState extends State<_ReportsList> {
  bool _autoOpened = false;

  void _open(MyReport r) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReportDetailScreen(report: r, repo: widget.repo)),
      );

  @override
  void initState() {
    super.initState();
    final id = widget.openIncidentId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoOpened) return;
        _autoOpened = true;
        final match = widget.reports.where((r) => r.id == id);
        if (match.isNotEmpty) _open(match.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = widget.reports[i];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _open(r),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${reportCategoryLabel(r.category)} · ${_dateLabel(r.createdAt)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      StreamBuilder<bool>(
                        stream: widget.repo.watchHasReply(r.id),
                        builder: (context, s) => _Pill(replied: s.data == true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(r.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.replied});

  final bool replied;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: replied ? AppColors.accent : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        replied ? AppStrings.myReportsReplyReceived : AppStrings.myReportsInProgress,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: replied ? AppColors.background : AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Message d'origine + fil de réponses de l'équipe (lecture seule).
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.report, required this.repo});

  final MyReport report;
  final IncidentRepository repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(reportCategoryLabel(report.category))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_dateLabel(report.createdAt), style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(report.message),
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<IncidentReply>>(
              stream: repo.watchReplies(report.id),
              builder: (context, s) {
                if (s.hasError) {
                  return const Text(AppStrings.myReportsLoadError);
                }
                final replies = s.data ?? const <IncidentReply>[];
                if (replies.isEmpty) {
                  return const Text(AppStrings.myReportsNoReplyYet);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in replies)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppStrings.myReportsTeamReply} · ${_dateLabel(r.createdAt)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Text(r.text),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
