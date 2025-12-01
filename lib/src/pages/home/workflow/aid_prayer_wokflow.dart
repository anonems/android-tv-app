// Gestion du workflow pour les prières d'Aïd (plusieurs occurrences possibles).
// Aïd n'a pas d'iqama — on utilise la(les) heure(s) de la/les prière(s) d'Aïd.
import 'package:flutter/material.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/WorkFlowWidget.dart';
import 'package:mawaqit/src/pages/home/sub_screens/normal_home.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/pages/home/workflow/prayer_workflow_utils.dart' as prayer_utils;

/// Construit la liste des WorkFlowItem pour les prières d'Aïd aujourd'hui (si présentes)
Future<List<WorkFlowItem>> buildAidWorkflowItems({
  required MosqueManager mosqueManager,
  VoidCallback? onDone,
}) async {
  final now = mosqueManager.mosqueDate();
  final items = <WorkFlowItem>[];

  // Détecte si aujourd'hui est Aïd (utilise les helpers existants)
  try {
    if (!mosqueManager.isEidFirstDay(0)) {
      return items;
    }
  } catch (_) {
    // if helper missing, fallback to empty
  }

  // TODO: if mosqueManager exposes a specific list of Aid prayer times, use it.
  // Fallback: use actualTimes() as potential Aid times for the day
  final aidDates = mosqueManager.actualTimes();

  if (aidDates.isEmpty) return items;

  // Prefix: before first Aid prayer show normal screen
  final first = aidDates.first;
  items.add(WorkFlowItem(builder: (context, next) => NormalHomeSubScreen(), duration: first.difference(now), skip: now.isAfter(first)));

  // Generate video items for each Aid prayer occurrence
  final videoItems = await prayer_utils.makePrayerLiveWorkFlowItems(
    prayerKey: 'aid',
    label: 'Aïd',
    getOccurrences: () => aidDates,
    mosqueManager: mosqueManager,
    defaultMinutes: 30,
  );

  items.addAll(videoItems);

  // Suffix: after last aid prayer, return to normal home
  items.add(WorkFlowItem(builder: (context, next) => NormalHomeSubScreen()));

  return items;
}