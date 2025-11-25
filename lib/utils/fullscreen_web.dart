// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void enterFullscreenWeb() {
  html.document.documentElement?.requestFullscreen();
}

void exitFullscreenWeb() {
  html.document.exitFullscreen();
}
