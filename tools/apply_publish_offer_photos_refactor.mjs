import fs from 'node:fs';

const path = 'lib/pages/publish_offer_page.dart';
let text = fs.readFileSync(path, 'utf8');

const widgetImport =
  "import '../features/offers/presentation/widgets/publish_offer_photos_section.dart';\n";
const importAnchor = "import 'publish_offer_widgets.dart';\n";
const subcategoryValidator = '                              validator: (_) => null,\n';
const endMarker = '                          // VILLE + CP + AUTOCOMPLÉTION\n';

if (!text.includes(importAnchor)) {
  throw new Error('publish_offer_widgets import anchor not found');
}

if (!text.includes(widgetImport)) {
  text = text.replace(importAnchor, `${importAnchor}${widgetImport}`);
}

const end = text.indexOf(endMarker);
const start = text.lastIndexOf(subcategoryValidator, end);
if (start < 0 || end < 0 || start >= end) {
  throw new Error('subcategory/photos section anchors not found');
}

const replacement = `                              validator: (_) => null,
                            ),
                          if (_category != null) const SizedBox(height: 16),

                          // PHOTOS
                          PublishOfferPhotosSection(
                            visibleTileCount: _visiblePhotoTileCount,
                            maximumPhotos: _publishPhotoHardLimit,
                            selectedPhotos: _selectedPhotos,
                            selectedPhotoBytes: _selectedPhotoBytes,
                            onPhotoTap: _onPhotoTileTap,
                            onPhotoLongPress: _pickImage,
                            onPhotoRemove: _removePhotoAt,
                          ),
                          const SizedBox(height: 16),

`;

text = text.slice(0, start) + replacement + text.slice(end);

const legacyImport = "import '../widgets/photo_selector_tile.dart';\n";
const withoutLegacyImport = text.replace(legacyImport, '');
if (!withoutLegacyImport.includes('PhotoSelectorTile')) {
  text = withoutLegacyImport;
}

fs.writeFileSync(path, text, 'utf8');
console.log('Publish offer photos section extracted successfully.');
