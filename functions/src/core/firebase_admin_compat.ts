import {
  applicationDefault,
  cert,
  getApp,
  getApps,
  initializeApp as initializeModularApp,
  type App as FirebaseApp,
  type AppOptions as FirebaseAppOptions,
  type ServiceAccount,
} from "firebase-admin/app";
import {
  getAuth,
  type ActionCodeSettings,
  type Auth,
  type CreateRequest,
  type DecodedIdToken,
  type ListUsersResult,
  type SessionCookieOptions,
  type UpdateRequest,
  type UserImportOptions,
  type UserImportRecord,
  type UserRecord,
} from "firebase-admin/auth";
import {
  AggregateField as ModularAggregateField,
  FieldPath as ModularFieldPath,
  FieldValue as ModularFieldValue,
  Filter as ModularFilter,
  GeoPoint as ModularGeoPoint,
  Timestamp as ModularTimestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {
  getMessaging,
  type BatchResponse,
  type Message,
  type Messaging,
  type MulticastMessage,
  type SendResponse,
} from "firebase-admin/messaging";
import {
  getRemoteConfig,
  type RemoteConfig,
  type RemoteConfigTemplate,
} from "firebase-admin/remote-config";
import { getStorage, type Storage } from "firebase-admin/storage";

const liveApps = new Proxy([] as FirebaseApp[], {
  get(_target, property, receiver) {
    return Reflect.get(getApps(), property, receiver);
  },
  has(_target, property) {
    return property in getApps();
  },
  ownKeys() {
    return Reflect.ownKeys(getApps());
  },
  getOwnPropertyDescriptor(_target, property) {
    return Object.getOwnPropertyDescriptor(getApps(), property);
  },
});

namespace admin {
  export const apps: FirebaseApp[] = liveApps;

  export function initializeApp(
    options?: FirebaseAppOptions,
    name?: string,
  ): FirebaseApp {
    return name == null
      ? initializeModularApp(options)
      : initializeModularApp(options, name);
  }

  export function app(name?: string): FirebaseApp {
    return name == null ? getApp() : getApp(name);
  }

  export namespace app {
    export type App = FirebaseApp;
    export type AppOptions = FirebaseAppOptions;
  }

  export const credential = {
    applicationDefault,
    cert,
  };

  export namespace credential {
    export type ServiceAccount = import("firebase-admin/app").ServiceAccount;
  }

  export function firestore(
    appInstance?: FirebaseApp,
  ): FirebaseFirestore.Firestore {
    return appInstance == null
      ? getFirestore()
      : getFirestore(appInstance);
  }

  export namespace firestore {
    export const AggregateField = ModularAggregateField;
    export const FieldPath = ModularFieldPath;
    export const FieldValue = ModularFieldValue;
    export const Filter = ModularFilter;
    export const GeoPoint = ModularGeoPoint;
    export const Timestamp = ModularTimestamp;

    export type AggregateField<T> = FirebaseFirestore.AggregateField<T>;
    export type AggregateQuerySnapshot<T extends FirebaseFirestore.AggregateSpec> =
      FirebaseFirestore.AggregateQuerySnapshot<T>;
    export type AggregateSpec = FirebaseFirestore.AggregateSpec;
    export type BulkWriter = FirebaseFirestore.BulkWriter;
    export type CollectionReference<T = FirebaseFirestore.DocumentData> =
      FirebaseFirestore.CollectionReference<T>;
    export type DocumentData = FirebaseFirestore.DocumentData;
    export type DocumentReference<T = FirebaseFirestore.DocumentData> =
      FirebaseFirestore.DocumentReference<T>;
    export type DocumentSnapshot<T = FirebaseFirestore.DocumentData> =
      FirebaseFirestore.DocumentSnapshot<T>;
    export type FieldPath = FirebaseFirestore.FieldPath;
    export type FieldValue = FirebaseFirestore.FieldValue;
    export type Filter = FirebaseFirestore.Filter;
    export type Firestore = FirebaseFirestore.Firestore;
    export type GeoPoint = FirebaseFirestore.GeoPoint;
    export type OrderByDirection = FirebaseFirestore.OrderByDirection;
    export type PartialWithFieldValue<T> =
      FirebaseFirestore.PartialWithFieldValue<T>;
    export type Precondition = FirebaseFirestore.Precondition;
    export type Query<T = FirebaseFirestore.DocumentData> =
      FirebaseFirestore.Query<T>;
    export type QueryDocumentSnapshot<T = FirebaseFirestore.DocumentData> =
      FirebaseFirestore.QueryDocumentSnapshot<T>;
    export type QuerySnapshot<T = FirebaseFirestore.DocumentData> =
      FirebaseFirestore.QuerySnapshot<T>;
    export type SetOptions = FirebaseFirestore.SetOptions;
    export type Timestamp = FirebaseFirestore.Timestamp;
    export type Transaction = FirebaseFirestore.Transaction;
    export type UpdateData<T> = FirebaseFirestore.UpdateData<T>;
    export type WhereFilterOp = FirebaseFirestore.WhereFilterOp;
    export type WithFieldValue<T> = FirebaseFirestore.WithFieldValue<T>;
    export type WriteBatch = FirebaseFirestore.WriteBatch;
    export type WriteResult = FirebaseFirestore.WriteResult;
  }

  export function auth(appInstance?: FirebaseApp): Auth {
    return appInstance == null ? getAuth() : getAuth(appInstance);
  }

  export namespace auth {
    export type ActionCodeSettings =
      import("firebase-admin/auth").ActionCodeSettings;
    export type Auth = import("firebase-admin/auth").Auth;
    export type CreateRequest = import("firebase-admin/auth").CreateRequest;
    export type DecodedIdToken =
      import("firebase-admin/auth").DecodedIdToken;
    export type ListUsersResult =
      import("firebase-admin/auth").ListUsersResult;
    export type SessionCookieOptions =
      import("firebase-admin/auth").SessionCookieOptions;
    export type UpdateRequest = import("firebase-admin/auth").UpdateRequest;
    export type UserImportOptions =
      import("firebase-admin/auth").UserImportOptions;
    export type UserImportRecord =
      import("firebase-admin/auth").UserImportRecord;
    export type UserRecord = import("firebase-admin/auth").UserRecord;
  }

  // Utilisé par l'entrypoint legacy pour lire et publier la configuration
  // micro-IA. Son absence faisait échouer getMicroIaConfig à chaque appel
  // (« admin.remoteConfig is not a function »), qui retombait silencieusement
  // sur les valeurs par défaut.
  export function remoteConfig(appInstance?: FirebaseApp): RemoteConfig {
    return appInstance == null
      ? getRemoteConfig()
      : getRemoteConfig(appInstance);
  }

  export namespace remoteConfig {
    export type RemoteConfig = import("firebase-admin/remote-config").RemoteConfig;
    export type RemoteConfigTemplate =
      import("firebase-admin/remote-config").RemoteConfigTemplate;
  }

  export function storage(appInstance?: FirebaseApp): Storage {
    return appInstance == null ? getStorage() : getStorage(appInstance);
  }

  export namespace storage {
    export type Storage = import("firebase-admin/storage").Storage;
  }

  export function messaging(appInstance?: FirebaseApp): Messaging {
    return appInstance == null ? getMessaging() : getMessaging(appInstance);
  }

  export namespace messaging {
    export type BatchResponse =
      import("firebase-admin/messaging").BatchResponse;
    export type Message = import("firebase-admin/messaging").Message;
    export type Messaging = import("firebase-admin/messaging").Messaging;
    export type MulticastMessage =
      import("firebase-admin/messaging").MulticastMessage;
    export type SendResponse =
      import("firebase-admin/messaging").SendResponse;
  }
}

void (null as unknown as ServiceAccount);
void (null as unknown as ActionCodeSettings);
void (null as unknown as CreateRequest);
void (null as unknown as DecodedIdToken);
void (null as unknown as ListUsersResult);
void (null as unknown as SessionCookieOptions);
void (null as unknown as UpdateRequest);
void (null as unknown as UserImportOptions);
void (null as unknown as UserImportRecord);
void (null as unknown as UserRecord);
void (null as unknown as RemoteConfigTemplate);
void (null as unknown as BatchResponse);
void (null as unknown as Message);
void (null as unknown as MulticastMessage);
void (null as unknown as SendResponse);

export = admin;
