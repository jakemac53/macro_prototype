import 'macros/observable.dart';

class ObservableThing {
  @observable
  String _description;

  ObservableThing(this._description);
}
