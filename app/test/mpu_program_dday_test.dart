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
    expect(
      mpuSiteSignedDDay({"d_day": "D\u221214"}),
      14,
    );
  });

  test("mpuEffectiveDaysUntilDeadline prefers reg_date over stale d_day", () {
    final Map<String, dynamic> staleActiveBadge = {
      "d_day": "D-14",
      "reg_date": "2020.01.01(수) ~ 2020.01.02(목)",
    };
    final Map<String, dynamic> staleCompletedBadge = {
      "d_day": "D+60",
      "reg_date": "2099.12.01(월) ~ 2099.12.31(금)",
    };

    expect(mpuEffectiveDaysUntilDeadline(staleActiveBadge)! < 0, isTrue);
    expect(mpuListingIsCompleted(staleActiveBadge), isTrue);
    expect(mpuEffectiveDaysUntilDeadline(staleCompletedBadge)! > 0, isTrue);
    expect(mpuListingIsCompleted(staleCompletedBadge), isFalse);
  });

  test("mpuEffectiveDaysUntilDeadline falls back to d_day without reg_date", () {
    expect(
      mpuEffectiveDaysUntilDeadline({"d_day": "D-14"}),
      14,
    );
    expect(
      mpuListingIsCompleted({"d_day": "D+60"}),
      isTrue,
    );
  });
}
