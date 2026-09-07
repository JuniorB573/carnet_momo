import 'package:intl/intl.dart';

final NumberFormat _fmt = NumberFormat.decimalPattern('fr_FR');

String fmtF(num n) => '${_fmt.format(n)} F';
