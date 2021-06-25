import 'package:flutter/material.dart';

import 'macros/auto_dispose.dart';
import 'macros/functional_widget.dart';

void main() {
  runApp(const MyApp());
}

@FunctionalWidget(widgetName: 'MyApp')
Widget _buildApp(BuildContext context,
    {String? appTitle}) {
  return MaterialApp(
      title: appTitle ?? 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage());
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({ Key? key }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stateMachineProvider);
    return Column(
      children: [],
    );
  }
}

final stateMachineProvider = Provider<States>((ref) => InitialState());

@StateMachine(actions: Actions)
class States {
  States.initial() = InitialState;
  States.value(int value) = ValueState;
  States.end(int value) = EndState;

  @event(Actions.Init, when: {InitialState})
  ValueState init(InitialState init) =>
     ValueState(0);
  
  @event(Actions.Next, when: {ValueState})
  ValueState next(ValueState s) =>
     ValueState(s.value + 1);

  @event(Actions.End, when: {InitialState, ValueState})
  ValueState next(States s) =>
     s is InitialState ? EndState(0) : EndState((s as ValueState).value);
}

enum Actions {Init, Next, End}
