import 'macros/observable.dart';

class ObservableThing {
  @observable
  external String description;
  ObservableThing(String description) {
    this.description = description;
  }
}
