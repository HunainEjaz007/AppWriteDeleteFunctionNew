import 'package:app_write_fun/main.dart' as delete_all;
import 'package:app_write_fun/main_selected.dart' as delete_selected;

Future<void> main() async {
  print('Running delete_all_collections function locally...');
  final allResult = await delete_all.main(null);
  print('all result: $allResult');

  print('Running delete_selected_collections function locally...');
  final selectedResult = await delete_selected.main({
    'payload': {
      'collectionIds': <String>['example_collection_id']
    }
  });
  print('selected result: $selectedResult');
}