class ListingAiRequest {
  const ListingAiRequest({
    required this.input,
    this.city = '',
    this.category = '',
    this.languageCode = 'fr-FR',
  });

  final String input;
  final String city;
  final String category;
  final String languageCode;

  Map<String, dynamic> toCallablePayload() {
    return <String, dynamic>{
      'input': input,
      if (city.trim().isNotEmpty) 'city': city.trim(),
      if (category.trim().isNotEmpty) 'category': category.trim(),
      'languageCode': languageCode.trim().isEmpty ? 'fr-FR' : languageCode,
    };
  }
}
