import 'macros/observable.dart';

class WithObservableField {
  @observable
  String _description;
  WithObservableField(this._description);
}

@observable
class ObservableClass {
  String _description;
  String _name;
  ObservableClass(this._name, this._description);
}
