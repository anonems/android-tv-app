// GENERATED - gestion des occurrences multiples de Jumua via prayer_workflow_utils
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mawaqit/src/helpers/time_utils.dart';
import 'package:mawaqit/src/pages/home/sub_screens/AfterSalahAzkarScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/JummuaLive.dart';
import 'package:mawaqit/src/pages/home/sub_screens/normal_home.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/WorkFlowWidget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:provider/provider.dart';
import 'package:mawaqit/src/pages/home/workflow/prayer_workflow_utils.dart' as prayer_utils;

/// show the back screen during the jumuaa
class JumuaaWorkflowScreen extends StatelessWidget {
  const JumuaaWorkflowScreen({Key? key, this.onDone}) : super(key: key);
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.read<MosqueManager>();
    final now = mosqueManager.mosqueDate();

    final jumuaaTimeout = mosqueManager.mosqueConfig?.jumuaTimeout ?? 30;
    final salahTime = int.tryParse(mosqueManager.mosqueConfig!.duaAfterPrayerShowTimes[1]) ?? 0;

    final jumuaaTime = mosqueManager.activeJumuaaDate();
    final jumuaaEndTime = jumuaaTime.add(Duration(minutes: jumuaaTimeout));

    // FutureBuilder pour générer dynamiquement la liste (préfixe -> 0..n vidéo items -> suffixe)
    return FutureBuilder<List<WorkFlowItem>>(
      future: () async {
        final items = <WorkFlowItem>[];

        // Prefix: écran normal jusqu'à la première jumuaaTime
        items.add(
          WorkFlowItem(
            builder: (context, next) => NormalHomeSubScreen(),
            duration: jumuaaTime.difference(now),
            skip: now.isAfter(jumuaaTime),
          ),
        );

        // Générer les WorkFlowItem vidéo pour toutes les occurrences de Jumua aujourd'hui
        List<DateTime> getIqamaDatesForJumua() {
          // Si MosqueManager expose plusieurs dates de Jumua, utilisez-les ici.
          // Par défaut on renvoie la date active (singleton)
          final dt = mosqueManager.activeJumuaaDate();
          return dt != null ? [dt] : [];
        }

        final videoItems = await prayer_utils.makePrayerLiveWorkFlowItems(
          prayerKey: 'jumua',
          label: 'Jumua',
          getOccurrences: getIqamaDatesForJumua,
          mosqueManager: mosqueManager,
          defaultMinutes: jumuaaTimeout,
        );

        items.addAll(videoItems);

        // Suffix: after jumua, afficher l'écran normal pendant la durée du salahTime (comme avant)
        items.add(
          WorkFlowItem(
            builder: (context, next) => NormalHomeSubScreen(),
            duration: salahTime.minutes,
            skip: now.isAfter(jumuaaEndTime.add(salahTime.minutes)),
          ),
        );

        // Azkar after salah
        items.add(
          WorkFlowItem(
            builder: (context, next) => AfterSalahAzkar(onDone: onDone),
            debugDuration: 2.minutes,
            skip: now.isAfter(jumuaaEndTime.add((salahTime + 2).minutes)),
          ),
        );

        return items;
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ContinuesWorkFlowWidget(
            debug: true,
            workFlowItems: [
              WorkFlowItem(builder: (context, next) => Center(child: CircularProgressIndicator())),
            ],
          );
        }
        final items = snapshot.data ?? [];
        return ContinuesWorkFlowWidget(
          debug: true,
          workFlowItems: items,
        );
      },
    );
  }
}