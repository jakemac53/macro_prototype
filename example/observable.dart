import 'macros/observable.dart';

class ObservableThing {
  @observable
  String _description;
  ObservableThing(this._description);
  String get description => _description;
  set description(String val) {
    print('Setting description to ${val}');
    _description = val;
  }
}
