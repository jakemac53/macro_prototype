import 'macros/observable.dart';

class ObservableThing {
  @observable
  external String description;

  ObservableThing(String description) {
    // TODO: ugly - can't used field initializing formals etc
    this.description = description;
  }
}
