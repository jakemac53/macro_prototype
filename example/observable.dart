import 'macros/observable.dart';

class WithObservableField {
  @observable
  String _description;
  WithObservableField(this._description);
  String get description => _description;
  void set description(String val) {
    print('Setting description to ${val}');
    _description = val;
  }
}

@observable
class ObservableClass {
  String _description;
  String _name;
  ObservableClass(this._name, this._description);
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
}
