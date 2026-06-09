# Schéma Firestore - Trust + Business Guidance

## users/{userId}

Champs utiles :

{
  "displayName": "Nom utilisateur",
  "email": "email@example.com",
  "phone": "+590...",
  "region": "Guadeloupe",
  "department": "971",
  "city": "Baie-Mahault",
  "isProfessional": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}

---

## professional_profiles/{userId}

{
  "userId": "uid",
  "businessName": "Nom commercial",
  "description": "Description longue",
  "region": "Guadeloupe",
  "department": "971",
  "city": "Baie-Mahault",
  "serviceCategories": ["Jardinage", "Peinture"],
  "interventionCities": ["Baie-Mahault", "Les Abymes"],
  "experienceYears": 3,
  "siret": "00000000000000",
  "siretStatus": "en_attente",
  "averageRating": 4.8,
  "reviewCount": 12,
  "trustScore": 86,
  "badges": ["SIRET vérifié", "Très bien noté"],
  "portfolioImageUrls": [],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}

---

## siret_verifications/{verificationId}

{
  "userId": "uid",
  "siret": "00000000000000",
  "status": "en_attente",
  "businessName": "",
  "activityLabel": "",
  "region": "Guadeloupe",
  "department": "971",
  "city": "",
  "checkedAt": "timestamp",
  "source": "manual_admin_or_api",
  "adminNote": ""
}

---

## reviews/{reviewId}

{
  "offerId": "offer_id",
  "reviewerId": "uid_client",
  "reviewedUserId": "uid_prestataire",
  "reviewType": "provider",
  "rating": 5,
  "communication": 5,
  "punctuality": 5,
  "quality": 5,
  "budgetRespect": 4,
  "professionalism": 5,
  "comment": "Très bon travail",
  "createdAt": "timestamp",
  "status": "published"
}

---

## review_summaries/{userId}

{
  "userId": "uid",
  "averageRating": 4.8,
  "reviewCount": 12,
  "providerReviewCount": 10,
  "clientReviewCount": 2,
  "trustScore": 86,
  "updatedAt": "timestamp"
}

---

## business_regions/{regionCode}

{
  "regionCode": "guadeloupe",
  "name": "Guadeloupe",
  "departments": ["971"],
  "defaultCciId": "cci_guadeloupe",
  "defaultRegionOrgId": "region_guadeloupe",
  "enabled": true
}

---

## local_organizations/{organizationId}

{
  "regionCode": "guadeloupe",
  "type": "cci",
  "name": "CCI locale",
  "description": "Accompagnement création entreprise",
  "phone": "",
  "email": "",
  "website": "",
  "address": "",
  "services": ["Création entreprise", "Formalités", "Accompagnement"],
  "enabled": true
}

---

## public_aids/{aidId}

{
  "regionCode": "guadeloupe",
  "title": "Aide publique à vérifier",
  "provider": "Région / organisme",
  "description": "Description courte",
  "eligibility": ["Créateur d'entreprise", "Projet local"],
  "link": "",
  "contactOrganizationId": "",
  "lastVerifiedAt": "timestamp",
  "enabled": true
}

---

## business_project_templates/{templateId}

{
  "projectType": "food_truck",
  "title": "Créer son food truck",
  "category": "Restauration",
  "defaultSteps": [
    "Définir le concept",
    "Choisir le statut juridique",
    "Vérifier les autorisations",
    "Préparer le budget",
    "Contacter les organismes locaux"
  ],
  "requiredDocuments": [
    "Pièce d'identité",
    "Justificatif de domicile",
    "Prévisionnel",
    "Assurance",
    "Documents véhicule"
  ],
  "enabled": true
}

---

## business_project_sheets/{sheetId}

{
  "userId": "uid",
  "regionCode": "guadeloupe",
  "department": "971",
  "city": "Baie-Mahault",
  "projectType": "food_truck",
  "title": "Créer mon food truck en Guadeloupe",
  "status": "draft",
  "summary": "",
  "steps": [],
  "organizations": [],
  "publicAids": [],
  "checklist": [],
  "estimatedBudgetMin": 0,
  "estimatedBudgetMax": 0,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
