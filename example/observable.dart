import 'macros/observable.dart';

class ObservableThing {
  String get description => _description;
  void set description(String val) {
    print('Setting description to ${val}');
    _description = val;
  }

  late String _description;

  ObservableThing(String description) {
    this.description = description;
  }
}
