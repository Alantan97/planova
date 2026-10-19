import 'package:sembast_web/sembast_web.dart';

Future<Database> openTaskDatabase() =>
    databaseFactoryWeb.openDatabase('planova_tasks.db');
