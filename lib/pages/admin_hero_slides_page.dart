import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/hero_slide.dart';
import '../services/hero_slides_service.dart';
import '../utils/friendly_snackbar.dart';

const _kAdminHeroOrange = Color(0xFFFF6600);
const _kAdminHeroBlue = Color(0xFF1A73E8);
const _kAdminHeroPageBackground = Color(0xFFF8F9FB);

/// Checklist manuelle rapide:
/// 1. Ajouter une image Hero et vérifier son apparition dans la liste.
/// 2. Ajouter une vidéo Hero, régler sa durée puis la définir en premier.
/// 3. Réordonner les slides, désactiver un slide puis le réactiver.
/// 4. Remplacer le média d'un slide existant puis vérifier que l'ancien fichier est supprimé.
/// 5. Supprimer le premier slide et vérifier qu'un autre slide actif devient premier.
class AdminHeroSlidesPage extends StatefulWidget {
  const AdminHeroSlidesPage({super.key});

  @override
  State<AdminHeroSlidesPage> createState() => _AdminHeroSlidesPageState();
}

class _AdminHeroSlidesPageState extends State<AdminHeroSlidesPage> {
  static const List<String> _imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> _videoExtensions = ['mp4', 'mov', 'webm'];
  static const int _maxImageBytes = 15 * 1024 * 1024;
  static const int _maxVideoBytes = 40 * 1024 * 1024;

  final HeroSlidesService _heroSlidesService = HeroSlidesService();
  final Set<String> _busySlideIds = <String>{};
  bool _isSubmitting = false;
  bool _isReordering = false;
  double? _uploadProgress;

  Future<void> _openSlideEditor({HeroSlide? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final durationController = TextEditingController(
      text: existing == null ? '' : existing.durationSeconds.toString(),
    );
    final orderController = TextEditingController(
      text: existing == null ? '' : existing.order.toString(),
    );
    var selectedBytes = <int>[];
    String selectedFileName = '';
    String selectedMediaType = existing?.mediaType ?? 'image';
    String selectedContentType = '';
    bool isActive = existing?.isActive ?? true;
    bool isFirst = existing?.isFirst ?? false;
    String localError = '';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickMedia() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: <String>[
                  ..._imageExtensions,
                  ..._videoExtensions,
                ],
                withData: true,
              );
              if (result == null || result.files.isEmpty) {
                return;
              }

              final file = result.files.single;
              final bytes = file.bytes;
              if (bytes == null) {
                setSheetState(() {
                  localError = 'Ce fichier ne peut pas être lu.';
                });
                return;
              }

              final mediaType = _mediaTypeFromName(file.name);
              final byteLimit = mediaType == 'video' ? _maxVideoBytes : _maxImageBytes;
              if (bytes.lengthInBytes > byteLimit) {
                setSheetState(() {
                  localError = mediaType == 'video'
                      ? 'La vidéo dépasse 40 Mo.'
                      : 'L\'image dépasse 15 Mo.';
                });
                return;
              }

              setSheetState(() {
                selectedBytes = bytes;
                selectedFileName = file.name;
                selectedMediaType = mediaType;
                selectedContentType = _contentTypeForName(file.name, mediaType);
                localError = '';
                if (existing == null && durationController.text.trim().isEmpty) {
                  durationController.text = mediaType == 'video' ? '10' : '5';
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing == null ? 'Ajouter un slide' : 'Modifier le slide',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ajoutez une image ou une vidéo, définissez sa durée et choisissez sa place dans le Hero.',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      InkWell(
                        onTap: _isSubmitting ? null : pickMedia,
                        borderRadius: BorderRadius.circular(18),
                        child: Ink(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: selectedMediaType == 'video'
                                      ? const Color(0xFFE8F0FE)
                                      : const Color(0xFFFFEFE5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  selectedMediaType == 'video'
                                      ? Icons.video_library_rounded
                                      : Icons.image_rounded,
                                  color: selectedMediaType == 'video'
                                      ? _kAdminHeroBlue
                                      : _kAdminHeroOrange,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedFileName.isEmpty
                                          ? 'Choisir un média'
                                          : selectedFileName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      selectedFileName.isEmpty
                                          ? 'Formats image: jpg, jpeg, png, webp. Formats vidéo: mp4, mov, webm.'
                                          : 'Type détecté: ${selectedMediaType == 'video' ? 'Vidéo' : 'Image'}',
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.upload_file_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre interne facultatif',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Durée (secondes)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: orderController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Ordre',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Slide actif'),
                        subtitle: const Text('Désactivez temporairement sans supprimer le slide.'),
                        value: isActive,
                        activeColor: _kAdminHeroOrange,
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setSheetState(() => isActive = value);
                              },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Définir comme premier slide'),
                        subtitle: const Text('Tous les autres slides perdront ce statut.'),
                        value: isFirst,
                        activeColor: _kAdminHeroBlue,
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setSheetState(() => isFirst = value);
                              },
                      ),
                      if (localError.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          localError,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (_isSubmitting) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: const Color(0xFFE5E7EB),
                          color: _kAdminHeroBlue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _uploadProgress == null
                              ? 'Upload en cours…'
                              : 'Upload en cours… ${(_uploadProgress! * 100).round()} %',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _kAdminHeroOrange,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _isSubmitting
                                  ? null
                                  : () async {
                                      if (existing == null && selectedBytes.isEmpty) {
                                        setSheetState(() {
                                          localError = 'Ajoutez un fichier image ou vidéo.';
                                        });
                                        return;
                                      }

                                      final parsedDuration = int.tryParse(
                                        durationController.text.trim(),
                                      );
                                      final parsedOrder = orderController.text.trim().isEmpty
                                          ? null
                                          : int.tryParse(orderController.text.trim());
                                      if (parsedDuration == null || parsedDuration < 1) {
                                        setSheetState(() {
                                          localError = 'La durée doit être un nombre supérieur à 0.';
                                        });
                                        return;
                                      }
                                      if (parsedOrder != null && parsedOrder < 0) {
                                        setSheetState(() {
                                          localError = 'L\'ordre doit être positif.';
                                        });
                                        return;
                                      }

                                      setState(() {
                                        _isSubmitting = true;
                                        _uploadProgress = null;
                                      });
                                      setSheetState(() {
                                        localError = '';
                                      });

                                      try {
                                        if (existing == null) {
                                          await _heroSlidesService.addSlide(
                                            fileBytes: Uint8List.fromList(selectedBytes),
                                            fileName: selectedFileName,
                                            mediaType: selectedMediaType,
                                            contentType: selectedContentType,
                                            title: titleController.text,
                                            durationSeconds: parsedDuration,
                                            order: parsedOrder,
                                            isActive: isActive,
                                            isFirst: isFirst,
                                            onUploadProgress: (progress) {
                                              if (!mounted) {
                                                return;
                                              }
                                              setState(() => _uploadProgress = progress);
                                            },
                                          );
                                          if (!mounted) {
                                            return;
                                          }
                                          if (!context.mounted) {
                                            return;
                                          }
                                          showSuccessSnackBar(
                                            context,
                                            'Slide Hero ajouté avec succès',
                                          );
                                        } else {
                                          await _heroSlidesService.updateSlide(
                                            existing,
                                            title: titleController.text,
                                            durationSeconds: parsedDuration,
                                            order: parsedOrder,
                                            isActive: isActive,
                                            isFirst: isFirst,
                                            replacementFileBytes: selectedBytes.isEmpty
                                                ? null
                                                : Uint8List.fromList(selectedBytes),
                                            replacementFileName: selectedFileName.isEmpty
                                                ? null
                                                : selectedFileName,
                                            replacementMediaType:
                                                selectedFileName.isEmpty ? null : selectedMediaType,
                                            replacementContentType:
                                                selectedFileName.isEmpty ? null : selectedContentType,
                                            onUploadProgress: (progress) {
                                              if (!mounted) {
                                                return;
                                              }
                                              setState(() => _uploadProgress = progress);
                                            },
                                          );
                                          if (!mounted) {
                                            return;
                                          }
                                          if (!context.mounted) {
                                            return;
                                          }
                                          showSuccessSnackBar(
                                            context,
                                            'Slide Hero mis à jour avec succès',
                                          );
                                        }

                                        if (!context.mounted) {
                                          return;
                                        }
                                        Navigator.of(context).pop(true);
                                      } catch (error) {
                                        if (!mounted) {
                                          return;
                                        }
                                        showErrorSnackBar(
                                          context,
                                          existing == null
                                              ? 'Impossible d’ajouter le slide. Vérifiez le fichier ou votre connexion.'
                                              : 'Impossible de modifier le slide. Vérifiez le fichier ou votre connexion.',
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isSubmitting = false;
                                            _uploadProgress = null;
                                          });
                                        }
                                      }
                                    },
                              child: Text(
                                existing == null
                                    ? 'Enregistrer le slide'
                                    : 'Enregistrer les modifications',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    durationController.dispose();
    orderController.dispose();

    if (saved == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteSlide(HeroSlide slide) async {
    if (_busySlideIds.contains(slide.id)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer ce slide ?'),
          content: const Text(
            'Voulez-vous vraiment supprimer ce slide du Hero ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _busySlideIds.add(slide.id));
    try {
      await _heroSlidesService.deleteSlide(slide);
      if (!mounted) {
        return;
      }
      showSuccessSnackBar(context, 'Slide Hero supprimé avec succès');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showErrorSnackBar(
        context,
        'Impossible de supprimer le slide. Vérifiez votre connexion.',
      );
    } finally {
      if (mounted) {
        setState(() => _busySlideIds.remove(slide.id));
      }
    }
  }

  Future<void> _setFirstSlide(HeroSlide slide) async {
    if (_busySlideIds.contains(slide.id)) {
      return;
    }
    setState(() => _busySlideIds.add(slide.id));
    try {
      await _heroSlidesService.setAsFirstSlide(slide.id);
      if (!mounted) {
        return;
      }
      showSuccessSnackBar(context, 'Premier slide mis à jour');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showErrorSnackBar(
        context,
        'Impossible de définir ce slide en premier.',
      );
    } finally {
      if (mounted) {
        setState(() => _busySlideIds.remove(slide.id));
      }
    }
  }

  Future<void> _toggleSlideActive(HeroSlide slide, bool value) async {
    if (_busySlideIds.contains(slide.id)) {
      return;
    }
    setState(() => _busySlideIds.add(slide.id));
    try {
      await _heroSlidesService.updateSlide(
        slide,
        isActive: value,
        isFirst: value ? slide.isFirst : false,
      );
      if (!mounted) {
        return;
      }
      showSuccessSnackBar(
        context,
        value ? 'Slide activé' : 'Slide désactivé',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showErrorSnackBar(
        context,
        'Impossible de mettre à jour ce slide.',
      );
    } finally {
      if (mounted) {
        setState(() => _busySlideIds.remove(slide.id));
      }
    }
  }

  Future<void> _reorderSlides(
    List<HeroSlide> slides,
    int oldIndex,
    int newIndex,
  ) async {
    if (_isReordering) {
      return;
    }

    final reordered = List<HeroSlide>.from(slides);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    setState(() => _isReordering = true);
    try {
      await _heroSlidesService.reorderSlides(reordered);
      if (!mounted) {
        return;
      }
      showSuccessSnackBar(context, 'Ordre des slides mis à jour');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showErrorSnackBar(
        context,
        'Impossible de réordonner les slides pour le moment.',
      );
    } finally {
      if (mounted) {
        setState(() => _isReordering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kAdminHeroPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'Gestion du Hero',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAdminHeroOrange,
        foregroundColor: Colors.white,
        onPressed: _isSubmitting ? null : _openSlideEditor,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('Ajouter un slide'),
      ),
      body: StreamBuilder<List<HeroSlide>>(
        stream: _heroSlidesService.watchAllSlidesForAdmin(),
        builder: (context, snapshot) {
          final slides = snapshot.data ?? const <HeroSlide>[];
          final isLoading = snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestion du Hero de la page d’accueil',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ajoutez des images ou vidéos qui seront affichées dans le Hero de la page Home. Vous pouvez définir l’ordre d’affichage, la durée et choisir le média affiché en premier.',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatChip(
                      color: _kAdminHeroBlue,
                      label: '${slides.where((slide) => slide.isActive).length} actifs',
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      color: _kAdminHeroOrange,
                      label: '${slides.length} total',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : slides.isEmpty
                          ? _EmptyHeroSlidesState(onAddPressed: _openSlideEditor)
                          : ReorderableListView.builder(
                              itemCount: slides.length,
                              onReorder: (oldIndex, newIndex) =>
                                  _reorderSlides(slides, oldIndex, newIndex),
                              buildDefaultDragHandles: false,
                              itemBuilder: (context, index) {
                                final slide = slides[index];
                                final isBusy =
                                    _busySlideIds.contains(slide.id) || _isSubmitting;
                                return Card(
                                  key: ValueKey(slide.id),
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _SlideMediaPreview(slide: slide),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: [
                                                      _TypeBadge(
                                                        color: slide.isVideo
                                                            ? _kAdminHeroBlue
                                                            : _kAdminHeroOrange,
                                                        label: slide.isVideo ? 'Vidéo' : 'Image',
                                                      ),
                                                      if (slide.isFirst)
                                                        const _TypeBadge(
                                                          color: Color(0xFF047857),
                                                          label: 'Premier slide',
                                                        ),
                                                      _TypeBadge(
                                                        color: slide.isActive
                                                            ? const Color(0xFF2563EB)
                                                            : const Color(0xFF9CA3AF),
                                                        label: slide.isActive ? 'Actif' : 'Inactif',
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    slide.title.trim().isEmpty
                                                        ? 'Sans titre interne'
                                                        : slide.title,
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.w900,
                                                      color: Color(0xFF111827),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Durée: ${slide.durationSeconds}s · Ordre: ${slide.order}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF6B7280),
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    slide.mediaUrl,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xFF9CA3AF),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: const Icon(
                                                Icons.drag_handle_rounded,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: SwitchListTile.adaptive(
                                                contentPadding: EdgeInsets.zero,
                                                title: const Text('Actif'),
                                                value: slide.isActive,
                                                activeColor: _kAdminHeroOrange,
                                                onChanged: isBusy
                                                    ? null
                                                    : (value) =>
                                                        _toggleSlideActive(slide, value),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: isBusy
                                                  ? null
                                                  : () => _openSlideEditor(existing: slide),
                                              icon: const Icon(Icons.edit_outlined),
                                              label: const Text('Modifier'),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: isBusy || slide.isFirst
                                                  ? null
                                                  : () => _setFirstSlide(slide),
                                              icon: const Icon(Icons.vertical_align_top_rounded),
                                              label: const Text('Définir en premier'),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: isBusy ? null : () => _deleteSlide(slide),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFFB91C1C),
                                              ),
                                              icon: const Icon(Icons.delete_outline_rounded),
                                              label: const Text('Supprimer'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _mediaTypeFromName(String name) {
    final extension = _extensionFromName(name);
    if (_videoExtensions.contains(extension)) {
      return 'video';
    }
    return 'image';
  }

  String _contentTypeForName(String fileName, String mediaType) {
    final extension = _extensionFromName(fileName);
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'mp4':
        return 'video/mp4';
      default:
        return mediaType == 'video' ? 'video/mp4' : 'image/jpeg';
    }
  }

  String _extensionFromName(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == name.length - 1) {
      return '';
    }
    return name.substring(dotIndex + 1).toLowerCase();
  }
}

class _SlideMediaPreview extends StatelessWidget {
  final HeroSlide slide;

  const _SlideMediaPreview({required this.slide});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 112,
        height: 88,
        child: slide.isVideo
            ? Container(
                color: const Color(0xFF111827),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'VIDÉO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              )
            : Image.network(
                slide.mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFFFF1E8),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: _kAdminHeroOrange,
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final Color color;
  final String label;

  const _StatChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final Color color;
  final String label;

  const _TypeBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyHeroSlidesState extends StatelessWidget {
  final VoidCallback onAddPressed;

  const _EmptyHeroSlidesState({required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEFE5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.slideshow_rounded,
                color: _kAdminHeroOrange,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Aucun slide Hero pour le moment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez une image ou une vidéo pour remplacer dynamiquement le Hero de la page Home.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _kAdminHeroOrange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('Ajouter un slide'),
            ),
          ],
        ),
      ),
    );
  }
}