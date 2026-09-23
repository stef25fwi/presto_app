part of 'publish_offer_page.dart';

extension _PublishOfferDraftLifecycle on _PublishOfferPageState {
  void _handlePublishTitleChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _titleEditedByUser = true;
    _markPublishDraftChanged();
  }

  void _handlePublishDescriptionChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _descriptionEditedByUser = true;
    _markPublishDraftChanged();
  }

  void _handlePublishLocationChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _locationEditedByUser = true;
    _markPublishDraftChanged();
  }

  void _handlePublishPostalCodeChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _postalCodeEditedByUser = true;
    _markPublishDraftChanged();
  }

  void _handlePublishBudgetChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _budgetEditedByUser = true;
    _markPublishDraftChanged();
  }

  void _handlePublishPhoneChanged() {
    if (_isApplyingProgrammaticPublishUpdate) return;
    _markPublishDraftChanged();
  }

  void _markPublishDraftChanged() {
    if (_isApplyingProgrammaticPublishUpdate || _publishDraftCompleted) return;
    _publishDraftTouched = true;
    if (!_publishDraftReady) return;
    _publishDraftSaveDebounce?.cancel();
    _publishDraftSaveDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_savePublishDraftNow()),
    );
  }

  PublishOfferDraft? _capturePublishDraft({String? ownerIdOverride}) {
    final ownerId = (ownerIdOverride ?? _publishDraftOwnerId)?.trim();
    if (ownerId == null || ownerId.isEmpty) return null;
    return PublishOfferDraft(
      ownerId: ownerId,
      savedAt: DateTime.now(),
      title: _titleController.text,
      description: _descriptionController.text,
      city: _locationController.text,
      postalCode: _postalCodeController.text,
      phone: _phoneController.text,
      phoneCountryCode: _selectedPhoneCountryCode,
      category: _category,
      subcategory: _selectedSubCategory,
      missionDelay: _missionDelay,
      budgetType: _budgetType,
      budget: _budgetController.text,
      hidePhone: _hidePhone,
    );
  }

  Future<void> _queuePublishDraftOperation(
    Future<void> Function() operation,
  ) {
    _publishDraftWriteQueue = _publishDraftWriteQueue.then((_) async {
      try {
        await operation();
      } catch (error) {
        debugPrint('[PublishDraft] local operation failed: $error');
      }
    });
    return _publishDraftWriteQueue;
  }

  Future<void> _savePublishDraftNow({String? ownerIdOverride}) {
    _publishDraftSaveDebounce?.cancel();
    _publishDraftSaveDebounce = null;
    final draft = _capturePublishDraft(ownerIdOverride: ownerIdOverride);
    if (draft == null) return Future<void>.value();
    return _queuePublishDraftOperation(() => _publishDraftStore.save(draft));
  }

  Future<void> _clearPublishDraft({String? ownerIdOverride}) {
    _publishDraftSaveDebounce?.cancel();
    _publishDraftSaveDebounce = null;
    final ownerId = (ownerIdOverride ?? _publishDraftOwnerId)?.trim();
    if (ownerId == null || ownerId.isEmpty) return Future<void>.value();
    return _queuePublishDraftOperation(
      () => _publishDraftStore.clearForOwner(ownerId),
    );
  }

  Future<void> _restorePublishDraftThenPrefill() async {
    final ownerId = _publishDraftOwnerId;
    PublishOfferDraft? draft;
    if (ownerId != null && ownerId.isNotEmpty) {
      try {
        draft = await _publishDraftStore.loadForOwner(ownerId);
      } catch (error) {
        debugPrint('[PublishDraft] local restore failed: $error');
      }
    }
    if (!mounted) return;

    final shouldRestore = draft != null && !_publishDraftTouched;
    if (shouldRestore) {
      _applyRestoredPublishDraft(draft);
    }
    _publishDraftReady = true;
    if (_publishDraftTouched) {
      unawaited(_savePublishDraftNow());
    }

    if (widget.draftOwnerIdForTesting == null) {
      await _prefillPublishFromProfile();
    }
  }

  void _applyRestoredPublishDraft(PublishOfferDraft draft) {
    final restoredCategory = _categories.contains(draft.category)
        ? draft.category
        : null;
    final availableSubcategories = restoredCategory == null
        ? const <String>[]
        : (kCategorySubcategories[restoredCategory] ?? const <String>[]);
    final restoredSubcategory =
        availableSubcategories.contains(draft.subcategory)
            ? draft.subcategory
            : null;
    final restoredDelay = _missionDelayOptions.contains(draft.missionDelay)
        ? draft.missionDelay
        : null;
    final restoredBudgetType = _budgetTypes.contains(draft.budgetType)
        ? draft.budgetType
        : 'Fixe';
    final knownPhoneCodes =
        kPhoneCountryCodes.map((country) => country.code).toSet();
    final restoredPhoneCode = knownPhoneCodes.contains(draft.phoneCountryCode)
        ? draft.phoneCountryCode
        : '+33';

    _runWithoutMarkingUserEdits(() {
      setState(() {
        _setControllerText(_titleController, draft.title);
        _setControllerText(_descriptionController, draft.description);
        _setControllerText(_locationController, draft.city);
        _setControllerText(_postalCodeController, draft.postalCode);
        _setControllerText(_phoneController, draft.phone);
        _setControllerText(_budgetController, draft.budget);
        _selectedPhoneCountryCode = restoredPhoneCode;
        _category = restoredCategory;
        _selectedSubCategory = restoredSubcategory;
        _missionDelay = restoredDelay;
        _isUrgent = restoredDelay == 'Urgent';
        _budgetType = restoredBudgetType;
        _hidePhone = draft.hidePhone;
        _manualEntryEnabled = true;
        _descriptionTapToEditPrimed = false;
        _publishAiFlowStep = PublishOfferAiFlowStep.chooseMethod;
        _titleEditedByUser = draft.title.trim().isNotEmpty;
        _descriptionEditedByUser = draft.description.trim().isNotEmpty;
        _locationEditedByUser = draft.city.trim().isNotEmpty;
        _postalCodeEditedByUser = draft.postalCode.trim().isNotEmpty;
        _categoryEditedByUser = restoredCategory != null;
        _delayEditedByUser = restoredDelay != null;
        _budgetEditedByUser = draft.budget.trim().isNotEmpty ||
            restoredBudgetType != 'Fixe';
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recompute();
    });
  }
}
