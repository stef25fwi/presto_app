import 'package:cloud_functions/cloud_functions.dart';

const kFirebaseFunctionsRegion = 'us-east1';

FirebaseFunctions get prestoFirebaseFunctions =>
    FirebaseFunctions.instanceFor(region: kFirebaseFunctionsRegion);
