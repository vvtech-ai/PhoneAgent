import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/home/presentation/widgets/home_hero.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 375.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('礼包资源及完整36像素区域保持邀请导航 $platform $width $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var modelsOpened = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: HomeHero(
                        slogan: const HomeSlogan('synthetic', '合成标题', '合成说明'),
                        modelName: '较长的合成模型名称',
                        modelMultiplier: 2,
                        onModels: () => modelsOpened++,
                        onWelfare: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const Scaffold(body: Text('合成邀请流程')),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = find.byKey(const Key('home-welfare'));
          final image = find.descendant(
            of: button,
            matching: find.byType(SvgPicture),
          );
          expect(image, findsOneWidget);
          expect(
            (tester.widget<SvgPicture>(image).bytesLoader as SvgAssetLoader)
                .assetName,
            'assets/images/shell/home_welfare_gift.svg',
          );
          expect(tester.getSize(button), const Size(36, 36));
          expect(tester.widget<IconButton>(button).tooltip, '福利');
          final rect = tester.getRect(button);
          for (final position in [
            rect.center,
            rect.topLeft + const Offset(1, 1),
            rect.bottomRight - const Offset(1, 1),
          ]) {
            await tester.tapAt(position);
            await tester.pumpAndSettle();
            expect(find.text('合成邀请流程'), findsOneWidget);
            expect(modelsOpened, 0);
            Navigator.of(tester.element(find.text('合成邀请流程'))).pop();
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('未开放福利时不显示礼包入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeHero(
            slogan: const HomeSlogan('synthetic', '合成标题', '合成说明'),
            modelName: '合成模型',
            onModels: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('home-welfare')), findsNothing);
    expect(find.byType(SvgPicture), findsNothing);
  });
}
