const widget = _FunctionalWidgetAnnotation();

class _FunctionalWidgetAnnotation {
  const _FunctionalWidgetAnnotation();
}

const autoDispose = _AutoDispose();

class _AutoDispose {
  const _AutoDispose();
}

// Interface for disposable things.
abstract class Disposable {
  void dispose();
}
