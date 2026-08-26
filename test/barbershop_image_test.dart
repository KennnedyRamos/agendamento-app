import 'package:agendamento_app/app/widgets/barbershop_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the selected logo before the fallback image',
      (tester) async {
    const onePixelPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

    await tester.pumpWidget(
      const MaterialApp(
        home: BarbershopImage(logoData: onePixelPng),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
  });

  testWidgets('keeps the default image when no logo was selected',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BarbershopImage()),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
  });
}
