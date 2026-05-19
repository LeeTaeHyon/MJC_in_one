export "notice_image_download_platform_stub.dart"
    if (dart.library.io) "notice_image_download_platform_io.dart"
    if (dart.library.html) "notice_image_download_platform_web.dart";
