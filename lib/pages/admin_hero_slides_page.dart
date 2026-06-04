import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/hero_slide.dart';
import '../services/hero_slides_service.dart';
import '../utils/friendly_snackbar.dart';
import '../utils/runtime_action_logger.dart';
import '../widgets/hero_local_video_preview.dart';

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
  static const int _maxImageBytes = 8 * 1024 * 1024;
  static const int _maxVideoBytes = 50 * 1024 * 1024;

  final HeroSlidesService _heroSlidesService = HeroSlidesService();
  final Set<String> _busySlideIds = <String>{};
  bool _isSubmitting = false;
  bool _isReordering = false;
  double? _uploadProgress;

  Future<void> _openSlideEditor({HeroSlide? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final durationController = TextEditingController(
      text: existing == null ? '5' : existing.durationSeconds.toString(),
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
    String previewWarning = '';
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
              if (!_isSupportedHeroMedia(file.name)) {
                setSheetState(() {
                  localError =
                      'Format non supporté. Utilisez une image JPG, PNG, WEBP ou une vidéo MP4.';
                });
                return;
              }
              final byteLimit =
                  mediaType == 'video' ? _maxVideoBytes : _maxImageBytes;
              if (bytes.lengthInBytes > byteLimit) {
                setSheetState(() {
                  localError =
                      'Fichier trop lourd. Réduisez la taille du média avant l’envoi.';
                });
                return;
              }

              setSheetState(() {
                selectedBytes = bytes;
                selectedFileName = file.name;
                selectedMediaType = mediaType;
                selectedContentType = _contentTypeForName(file.name, mediaType);
                previewWarning = '';
                localError = '';
                if (existing == null) {
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
                        existing == null
                            ? 'Ajouter un slide Hero'
                            : 'Modifier le slide',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ajoutez une image ou une vidéo, définissez sa durée et choisissez sa place dans le Hero de la Home.',
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
                                          ? 'Choisir une image ou une vidéo'
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
                      if (selectedBytes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SelectedHeroMediaPreview(
                          fileBytes: selectedBytes,
                          fileName: selectedFileName,
                          mediaType: selectedMediaType,
                          contentType: selectedContentType,
                          onClear: _isSubmitting
                              ? null
                              : () {
                                  setSheetState(() {
                                    selectedBytes = <int>[];
                                    selectedFileName = '';
                                    selectedMediaType =
                                        existing?.mediaType ?? 'image';
                                    selectedContentType = '';
                                    previewWarning = '';
                                  });
                                },
                          onPreviewError: (message) {
                            setSheetState(() {
                              previewWarning = message;
                            });
                            logRuntimeAction(
                              area: 'admin-hero',
                              action: 'selected-preview-error',
                              details: <String, Object?>{
                                'fileName': selectedFileName,
                                'mediaType': selectedMediaType,
                                'contentType': selectedContentType,
                              },
                            );
                          },
                          onPreviewReady: () {
                            if (previewWarning.isEmpty) {
                              return;
                            }
                            setSheetState(() {
                              previewWarning = '';
                            });
                          },
                        ),
                        if (previewWarning.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            previewWarning,
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titre interne',
                          hintText:
                              'Exemple : Hero lancement, Promo été, Vidéo accueil',
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
                                helperText:
                                    'Cette durée détermine combien de temps le slide reste visible dans le Hero.',
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
                        title: const Text('Activer ce slide immédiatement'),
                        subtitle: const Text(
                            'Désactivez temporairement sans supprimer le slide.'),
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
                        title: const Text('Afficher ce slide en premier'),
                        subtitle: const Text(
                            'Tous les autres slides perdront ce statut.'),
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
                                      if (existing == null &&
                                          selectedBytes.isEmpty) {
                                        setSheetState(() {
                                          localError =
                                              'Ajoutez un fichier image ou vidéo.';
                                        });
                                        return;
                                      }

                                      final parsedDuration = int.tryParse(
                                        durationController.text.trim(),
                                      );
                                      final parsedOrder =
                                          orderController.text.trim().isEmpty
                                              ? null
                                              : int.tryParse(
                                                  orderController.text.trim());
                                      if (parsedDuration == null ||
                                          parsedDuration < 3 ||
                                          parsedDuration > 60) {
                                        setSheetState(() {
                                          localError =
                                              'La durée doit être comprise entre 3 et 60 secondes.';
                                        });
                                        return;
                                      }
                                      if (parsedOrder != null &&
                                          parsedOrder < 0) {
                                        setSheetState(() {
                                          localError =
                                              'L\'ordre doit être positif.';
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
                                            fileBytes: Uint8List.fromList(
                                                selectedBytes),
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
                                              setState(() =>
                                                  _uploadProgress = progress);
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
                                            replacementFileBytes:
                                                selectedBytes.isEmpty
                                                    ? null
                                                    : Uint8List.fromList(
                                                        selectedBytes),
                                            replacementFileName:
                                                selectedFileName.isEmpty
                                                    ? null
                                                    : selectedFileName,
                                            replacementMediaType:
                                                selectedFileName.isEmpty
                                                    ? null
                                                    : selectedMediaType,
                                            replacementContentType:
                                                selectedFileName.isEmpty
                                                    ? null
                                                    : selectedContentType,
                                            onUploadProgress: (progress) {
                                              if (!mounted) {
                                                return;
                                              }
                                              setState(() =>
                                                  _uploadProgress = progress);
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
            'Ce média sera retiré du Hero de la page Home. Cette action est définitive.',
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
      showSuccessSnackBar(context, 'Slide supprimé avec succès');
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
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        elevation: 1,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF374151)),
        title: const Text(
          'Gestion du Hero',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<List<HeroSlide>>(
        stream: _heroSlidesService.watchAllSlidesForAdmin(),
        builder: (context, snapshot) {
          final slides = snapshot.data ?? const <HeroSlide>[];
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;
          final activeCount = slides.where((slide) => slide.isActive).length;
          final imageCount = slides.where((slide) => slide.isImage).length;
          final videoCount = slides.where((slide) => slide.isVideo).length;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroIntroCard(
                      hasSlides: slides.isNotEmpty,
                      onAddPressed: _isSubmitting ? null : _openSlideEditor,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _HeroStatCard(
                          label: 'actifs',
                          value: activeCount.toString(),
                          icon: Icons.check_circle_rounded,
                          backgroundColor: const Color(0xFFE8F0FE),
                          foregroundColor: _kAdminHeroBlue,
                        ),
                        _HeroStatCard(
                          label: 'total',
                          value: slides.length.toString(),
                          icon: Icons.layers_rounded,
                          backgroundColor: const Color(0xFFFFF1E8),
                          foregroundColor: _kAdminHeroOrange,
                        ),
                        _HeroStatCard(
                          label: 'images',
                          value: imageCount.toString(),
                          icon: Icons.image_rounded,
                          backgroundColor: const Color(0xFFF3F4F6),
                          foregroundColor: const Color(0xFF374151),
                        ),
                        _HeroStatCard(
                          label: 'vidéos',
                          value: videoCount.toString(),
                          icon: Icons.video_library_rounded,
                          backgroundColor: const Color(0xFFEEF2FF),
                          foregroundColor: const Color(0xFF4F46E5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.hasError)
                      _HeroSlidesErrorState(onRetry: () => setState(() {}))
                    else if (!isLoading && slides.isNotEmpty) ...[
                      _HeroSlidesThumbnailCarousel(
                        slides: slides,
                        onSlideTap: (slide) =>
                            _openSlideEditor(existing: slide),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Expanded(
                      child: isLoading
                          ? const _HeroSlidesLoadingState()
                          : snapshot.hasError
                              ? const SizedBox.shrink()
                              : slides.isEmpty
                                  ? _EmptyHeroSlidesState(
                                      onAddPressed: _openSlideEditor)
                                  : ReorderableListView.builder(
                                      itemCount: slides.length,
                                      onReorder: (oldIndex, newIndex) =>
                                          _reorderSlides(
                                              slides, oldIndex, newIndex),
                                      buildDefaultDragHandles: false,
                                      itemBuilder: (context, index) {
                                        final slide = slides[index];
                                        final isBusy =
                                            _busySlideIds.contains(slide.id) ||
                                                _isSubmitting;
                                        return Card(
                                          key: ValueKey(slide.id),
                                          elevation: 0,
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            side: const BorderSide(
                                              color: Color(0xFFE5E7EB),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _SlideMediaPreview(
                                                        slide: slide),
                                                    const SizedBox(width: 14),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Wrap(
                                                            spacing: 8,
                                                            runSpacing: 8,
                                                            children: [
                                                              _TypeBadge(
                                                                color: slide
                                                                        .isVideo
                                                                    ? _kAdminHeroBlue
                                                                    : _kAdminHeroOrange,
                                                                label: slide
                                                                        .isVideo
                                                                    ? 'Vidéo'
                                                                    : 'Image',
                                                              ),
                                                              if (slide.isFirst)
                                                                const _TypeBadge(
                                                                  color: Color(
                                                                      0xFF047857),
                                                                  label:
                                                                      'Premier slide',
                                                                ),
                                                              _TypeBadge(
                                                                color: slide
                                                                        .isActive
                                                                    ? const Color(
                                                                        0xFF2563EB)
                                                                    : const Color(
                                                                        0xFF9CA3AF),
                                                                label: slide
                                                                        .isActive
                                                                    ? 'Actif'
                                                                    : 'Inactif',
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 10),
                                                          Text(
                                                            slide.title
                                                                    .trim()
                                                                    .isEmpty
                                                                ? 'Sans titre interne'
                                                                : slide.title,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 17,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              color: Color(
                                                                  0xFF111827),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 6),
                                                          Text(
                                                            '${slide.durationSeconds} secondes · Position ${index + 1}',
                                                            style:
                                                                const TextStyle(
                                                              color: Color(
                                                                  0xFF6B7280),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            slide.mediaUrl,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              color: Color(
                                                                  0xFF9CA3AF),
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    ReorderableDragStartListener(
                                                      index: index,
                                                      child: const Icon(
                                                        Icons
                                                            .drag_handle_rounded,
                                                        color:
                                                            Color(0xFF9CA3AF),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: SwitchListTile
                                                          .adaptive(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title:
                                                            const Text('Actif'),
                                                        value: slide.isActive,
                                                        activeColor:
                                                            _kAdminHeroOrange,
                                                        onChanged: isBusy
                                                            ? null
                                                            : (value) =>
                                                                _toggleSlideActive(
                                                                    slide,
                                                                    value),
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
                                                          : () =>
                                                              _openSlideEditor(
                                                                  existing:
                                                                      slide),
                                                      icon: const Icon(
                                                          Icons.edit_outlined),
                                                      label: const Text(
                                                          'Modifier'),
                                                    ),
                                                    OutlinedButton.icon(
                                                      onPressed: isBusy ||
                                                              slide.isFirst
                                                          ? null
                                                          : () =>
                                                              _setFirstSlide(
                                                                  slide),
                                                      icon: const Icon(Icons
                                                          .vertical_align_top_rounded),
                                                      label: const Text(
                                                          'Définir en premier'),
                                                    ),
                                                    OutlinedButton.icon(
                                                      onPressed: isBusy
                                                          ? null
                                                          : () => _deleteSlide(
                                                              slide),
                                                      style: OutlinedButton
                                                          .styleFrom(
                                                        foregroundColor:
                                                            const Color(
                                                                0xFFB91C1C),
                                                      ),
                                                      icon: const Icon(Icons
                                                          .delete_outline_rounded),
                                                      label: const Text(
                                                          'Supprimer'),
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
              ),
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

  bool _isSupportedHeroMedia(String name) {
    final extension = _extensionFromName(name);
    return _imageExtensions.contains(extension) ||
        _videoExtensions.contains(extension);
  }
}

class _HeroIntroCard extends StatelessWidget {
  final bool hasSlides;
  final VoidCallback? onAddPressed;

  const _HeroIntroCard({
    required this.hasSlides,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 680;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.slideshow_rounded,
                      color: _kAdminHeroBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hero de la page d’accueil',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Gérez ici les images et vidéos affichées dans le Hero de la page Home. Vous pouvez choisir le premier média affiché, définir la durée, modifier l’ordre et activer ou désactiver chaque slide.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          );

          final addButton = hasSlides
              ? FilledButton.icon(
                  onPressed: onAddPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kAdminHeroOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Ajouter un slide'),
                )
              : const SizedBox.shrink();

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                if (hasSlides) ...[
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: addButton),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: text),
              if (hasSlides) ...[
                const SizedBox(width: 20),
                addButton,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _HeroStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foregroundColor, size: 20),
          const SizedBox(width: 9),
          Text(
            value,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSlidesLoadingState extends StatelessWidget {
  const _HeroSlidesLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

class _HeroSlidesErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _HeroSlidesErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Impossible de charger les slides Hero pour le moment.',
              style: TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _SelectedHeroMediaPreview extends StatelessWidget {
  final List<int> fileBytes;
  final String fileName;
  final String mediaType;
  final String contentType;
  final VoidCallback? onClear;
  final ValueChanged<String>? onPreviewError;
  final VoidCallback? onPreviewReady;

  const _SelectedHeroMediaPreview({
    required this.fileBytes,
    required this.fileName,
    required this.mediaType,
    required this.contentType,
    this.onClear,
    this.onPreviewError,
    this.onPreviewReady,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = mediaType == 'video';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 96,
              height: 68,
              child: isVideo
                  ? HeroLocalVideoPreview(
                      bytes: Uint8List.fromList(fileBytes),
                      contentType: contentType,
                      onPreviewError: onPreviewError,
                      onPreviewReady: onPreviewReady,
                    )
                  : Image.memory(
                      Uint8List.fromList(fileBytes),
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isVideo ? 'Vidéo' : 'Image'} · $contentType',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      size: 16,
                      color: _kAdminHeroBlue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isVideo
                            ? 'Prévisualisation locale avant upload Firebase Storage'
                            : 'Upload Firebase Storage: hero_slides/',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _kAdminHeroBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Retirer ce fichier',
              onPressed: onClear,
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroSlidesThumbnailCarousel extends StatelessWidget {
  final List<HeroSlide> slides;
  final void Function(HeroSlide slide) onSlideTap;

  const _HeroSlidesThumbnailCarousel({
    required this.slides,
    required this.onSlideTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.view_carousel_outlined, color: _kAdminHeroBlue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Prévisualisation des slides Hero',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: slides.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final slide = slides[index];
                return _HeroSlideThumbnail(
                  slide: slide,
                  position: index + 1,
                  onTap: () => onSlideTap(slide),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSlideThumbnail extends StatelessWidget {
  final HeroSlide slide;
  final int position;
  final VoidCallback onTap;

  const _HeroSlideThumbnail({
    required this.slide,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 148,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: slide.isFirst
                ? const Color(0xFF047857)
                : const Color(0xFFE5E7EB),
            width: slide.isFirst ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 74,
                child: slide.isVideo
                    ? Container(
                        color: const Color(0xFF111827),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 30,
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 0),
              child: Row(
                children: [
                  Text(
                    '#$position',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      slide.title.trim().isEmpty ? 'Slide Hero' : slide.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 3, 9, 0),
              child: Text(
                '${slide.isVideo ? 'Vidéo' : 'Image'} · ${slide.durationSeconds}s${slide.isFirst ? ' · premier' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: slide.isActive
                      ? _kAdminHeroBlue
                      : const Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            slide.isVideo
                ? Container(
                    color: const Color(0xFF111827),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 34,
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
            Positioned(
              left: 7,
              top: 7,
              child: _MediaOverlayBadge(
                label: slide.isVideo ? 'VIDÉO' : 'IMAGE',
                color: slide.isVideo ? _kAdminHeroBlue : _kAdminHeroOrange,
              ),
            ),
            if (slide.isFirst)
              const Positioned(
                right: 7,
                top: 7,
                child: _MediaOverlayBadge(
                  label: 'Premier',
                  color: Color(0xFF047857),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaOverlayBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MediaOverlayBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
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
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
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
                Icons.photo_library_rounded,
                color: _kAdminHeroOrange,
                size: 36,
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
              'Ajoutez une image ou une vidéo pour personnaliser dynamiquement le Hero de la page Home.',
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
              label: const Text('Ajouter le premier slide'),
            ),
          ],
        ),
      ),
    );
  }
}
