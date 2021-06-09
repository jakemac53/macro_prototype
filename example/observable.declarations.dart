import 'macros/observable.dart';

class ObservableThing {
  @observable
  String _description;
  String get description => _description;
  void set description(String val) {
    print('Setting description to ${val}');
    _description = val;
  }

  ObservableThing(this._description);
}
