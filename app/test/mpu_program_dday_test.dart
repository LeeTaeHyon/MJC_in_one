import "package:flutter_test/flutter_test.dart";
import "package:mjc_in_one/utils/mpu_program_dday.dart";

void main() {
  test("mpuSiteSignedDDay parses MPU site badge values", () {
    expect(
      mpuSiteSignedDDay({"d_day": "D-14"}),
      14,
    );
    expect(
      mpuSiteSignedDDay({"d_day": "d+88"}),
      -88,
    );
    expect(mpuSiteSignedDDay({"d_day": "D-DAY"}), isNull);
  });

  test("mpuListingIsCompleted prefers crawled d_day over reg_date", () {
    final Map<String, dynamic> active = {
      "d_day": "D-14",
      "reg_date": "2026.03.13(금) ~ 2026.03.29(일)",
    };
    final Map<String, dynamic> completed = {
      "d_day": "D+60",
      "reg_date": "2026.05.26(화) ~ 2026.06.12(금)",
    };

    expect(mpuListingIsCompleted(active), isFalse);
    expect(mpuListingIsCompleted(completed), isTrue);
  });
}
