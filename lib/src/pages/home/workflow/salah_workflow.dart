// GENERATED - Intégration des WorkFlowItem vidéo après l'iqama (Fajr, Dhuhr, Asr, Maghrib, Isha)
// Remplace le return ContinuesWorkFlowWidget(...) original par un FutureBuilder
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mawaqit/src/helpers/time_utils.dart';
import 'package:mawaqit/src/pages/home/sub_screens/AfterSalahAzkarScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/AdhanSubScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/IqamaSubScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/IqamaaCountDownSubScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/AfterAdhanSubScreen.dart';
import 'package:mawaqit/src/pages/home/sub_screens/normal_home.dart';
import 'package:mawaqit/src/pages/home/sub_screens/DuaaBetweenAdhanAndIqamaa.dart';
import 'package:mawaqit/src/pages/home/widgets/workflows/WorkFlowWidget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:provider/provider.dart';
import 'package:mawaqit/src/pages/home/workflow/prayer_workflow_utils.dart' as prayer_utils;
import 'package:mawaqit/src/helpers/AppDate.dart' show AppDateTime;

/// SalahWorkflowScreen : gère le workflow d'une prière (Adhan/Iqama/etc)
class SalahWorkflowScreen extends StatefulWidget {
  const SalahWorkflowScreen({Key? key, this.onDone}) : super(key: key);
  final VoidCallback? onDone;

  @override
  State<SalahWorkflowScreen> createState() => _SalahWorkflowScreenState();
}

class _SalahWorkflowScreenState extends State<SalahWorkflowScreen> {
  @override
  Widget build(BuildContext context) {
    final mosqueManger = context.read<MosqueManager>();
    final now = mosqueManger.mosqueDate();
    final mosqueConfig = mosqueManger.mosqueConfig!;
    final currentSalah = mosqueManger.salahIndex;
    final currentSalahTime = mosqueManger.actualTimes()[currentSalah];
    final currentIqamaTime = mosqueManger.actualIqamaTimes()[currentSalah];
    final isFajrPray = mosqueManger.salahIndex == 0;
    final isAsrPray = mosqueManger.salahIndex == 2;
    final iqamaEndTime = currentIqamaTime.add(Duration(minutes: 1));
    final salahTime = mosqueManger.mosqueConfig!.duaAfterPrayerShowTimes[currentSalah];
    final salahEndTime = iqamaEndTime.add(
      Duration(minutes: int.tryParse(salahTime) ?? 0),
    );

    // Fonction utilitaire locale : renvoie List<DateTime> (0..1) pour l'iqama de la prière courante
    List<DateTime> getIqamaDatesForCurrent() {
      try {
        final iqamaTimes = mosqueManger.actualIqamaTimes();
        final dt = iqamaTimes[currentSalah];
        return dt != null ? [dt] : [];
      } catch (e) {
        return [];
      }
    }

    // Construction asynchrone de la liste complète de WorkFlowItem (base + vidéo + queue)
    return FutureBuilder<List<WorkFlowItem>>(
      future: () async {
        // Base items (avant adhan -> adhan -> after adhan -> duaa -> iqama countdown -> iqama display)
        final baseItems = <WorkFlowItem>[
          // before the adhan time
          WorkFlowItem(
            duration: mosqueManger.nextSalahAfter(),
            skip: mosqueManger.nextSalahAfter() > Duration(minutes: 6),
            builder: (context, next) => beforeSalahTime(mosqueManger, currentSalah, AppDateTime.now()),
          ),
          WorkFlowItem(
            builder: (context, next) => AdhanSubScreen(onDone: next),
          ),
          WorkFlowItem(
            builder: (context, next) => AfterAdhanSubScreen(onDone: next),
            disabled: mosqueConfig.duaAfterAzanEnabled == false,
          ),
          WorkFlowItem(
            builder: (context, next) => DuaaBetweenAdhanAndIqamaaScreen(
              onDone: next,
            ),
            disabled: mosqueConfig.duaAfterAzanEnabled == false,
            skip: true,
          ),
          WorkFlowItem(
            builder: (context, next) => IqamaaCountDownSubScreen(
              onDone: next,
              currentSalahIndex: currentSalah,
            ),
            skip: now.isAfter(currentIqamaTime),
            disabled: mosqueManger.mosqueConfig?.iqamaEnabled == false,
          ),
          WorkFlowItem(
            builder: (context, next) => IqamaSubScreen(),
            duration: Duration(seconds: mosqueConfig.iqamaDisplayTime ?? 30),
            skip: now.isAfter(iqamaEndTime),
            disabled: mosqueManger.mosqueConfig?.iqamaEnabled == false,
          ),
        ];

        // Générer les WorkFlowItem vidéos (0..n) pour cette prière via l'utilitaire
        final videoItems = await prayer_utils.makePrayerLiveWorkFlowItems(
          prayerKey: ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'][currentSalah],
          label: ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'][currentSalah],
          getOccurrences: getIqamaDatesForCurrent,
          mosqueManager: mosqueManger,
          defaultMinutes: 10,
        );

        // Suite des items après la période de prière
        final tailItems = <WorkFlowItem>[
          WorkFlowItem(
            builder: (context, next) =>
                mosqueConfig.blackScreenWhenPraying == true ? Container(color: Colors.black) : NormalHomeSubScreen(),
            skip: now.isAfter(salahEndTime),
            duration: mosqueManger.currentSalahDuration,
            disabled: mosqueConfig.iqamaEnabled == false,
          ),
          WorkFlowItem(
            builder: (context, next) => AfterSalahAzkar(onDone: next),
            disabled: mosqueConfig.iqamaEnabled == false,
          ),
          WorkFlowItem(
              duration: const Duration(minutes: 2), // debug default used originally as kAzkarDuration
              builder: (context, next) => AfterSalahAzkar(
                    // this is a redundant parameter as it is always should be (isFajrPray | isAsrPray)
                    isAfterAsrOrFajr: true,
                    isAfterAsr: isAsrPray,
                    azkarTitle:
                        isFajrPray ? AzkarConstant.kAzkarSabahAfterPrayer : AzkarConstant.kAzkarAsrAfterPrayer,
                  ),
              disabled: mosqueConfig.iqamaEnabled == false || (!isFajrPray && !isAsrPray)),
        ];

        return [...baseItems, ...videoItems, ...tailItems];
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Affichage temporaire pendant la génération (loader)
          return ContinuesWorkFlowWidget(
            onDone: widget.onDone,
            workFlowItems: [
              WorkFlowItem(builder: (context, next) => Center(child: CircularProgressIndicator())),
            ],
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          // Fallback simple en cas d'erreur
          return ContinuesWorkFlowWidget(
            onDone: widget.onDone,
            workFlowItems: [
              WorkFlowItem(builder: (context, next) => Center(child: Text('Erreur chargement planning vidéo'))),
            ],
          );
        }
        final items = snapshot.data!;
        return ContinuesWorkFlowWidget(
          onDone: widget.onDone,
          workFlowItems: items,
        );
      },
    );
  }
}