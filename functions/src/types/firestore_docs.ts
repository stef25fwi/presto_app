export interface FirestoreCollectionSchema {
  name: string;
  required_fields: string[];
  indexes: string[];
  relations: string[];
}

export const firestoreSchemas: FirestoreCollectionSchema[] = [
  {
    name: "users",
    required_fields: ["user_id", "email", "status", "created_at", "updated_at"],
    indexes: ["status+created_at", "email"],
    relations: ["notification_preferences:user_id", "user_profiles:user_id"],
  },
  {
    name: "listings",
    required_fields: ["listing_id", "owner_id", "title", "status", "created_at"],
    indexes: ["owner_id+status", "city+category+status", "status+published_at"],
    relations: ["users:owner_id", "favorites:listing_id"],
  },
  {
    name: "email_events",
    required_fields: ["event_id", "event_name", "source_collection", "source_id", "dedupe_key"],
    indexes: ["event_name+occurred_at", "dedupe_key", "status+occurred_at"],
    relations: ["email_jobs:event_id"],
  },
  {
    name: "email_jobs",
    required_fields: ["job_id", "event_id", "recipient_email", "template_code", "status", "send_at"],
    indexes: ["status+send_at+priority", "idempotency_key", "recipient_email+created_at"],
    relations: ["email_events:event_id", "email_logs:job_id"],
  },
  {
    name: "email_logs",
    required_fields: ["log_id", "job_id", "provider", "status", "created_at"],
    indexes: ["provider_message_id", "job_id", "status+created_at"],
    relations: ["email_jobs:job_id"],
  },
];
