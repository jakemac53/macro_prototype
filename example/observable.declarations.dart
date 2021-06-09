import 'macros/observable.dart';

class WithObservableField {
  @observable
  String _description;
  String get description => _description;
  void set description(String val) {
    print('Setting description to ${val}');
    _description = val;
  }

  WithObservableField(this._description);
}

@observable
class ObservableClass {
  String get description => _description;
  void set description(String val) {
    print('Setting description to ${val}');
    _description = val;
  }

  String get name => _name;
  void set name(String val) {
    print('Setting name to ${val}');
    _name = val;
  }

  String _description;
  String _name;
  ObservableClass(this._name, this._description);
}
