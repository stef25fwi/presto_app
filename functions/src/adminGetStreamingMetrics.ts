import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function to retrieve Streaming Micro IA metrics
 * 
 * Called by: StreamingMonitoringPage (admin space)
 * Returns: Real-time metrics about WebSocket streaming usage
 * 
 * TODO: Implement actual metrics collection from:
 * - Cloud Run logs
 * - Firestore events collection
 * - Cloud Pub/Sub for streaming events
 */

interface StreamingMetrics {
  totalRequests: number;
  successRate: number;      // 0-100
  averageLatency: number;   // milliseconds
  estimatedCost: number;    // USD
  activeStreams: number;
  errorCount: number;
  lastUpdated: string;
  backendStatus: 'online' | 'offline' | 'degraded';
  backendRegion: string;
  backendUrl: string;
  trends: Array<{
    timestamp: string;
    requestCount: number;
    averageLatency: number;
  }>;
}

export const adminGetStreamingMetrics = functions
  .region('europe-west1')
  .https.onCall(async (data, context) => {
    // Verify user is admin
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated',
      );
    }

    try {
      const uid = context.auth.uid;
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(uid)
        .get();

      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User not found',
        );
      }

      // TODO: Replace with actual admin role check
      // const isAdmin = userDoc.data()?.role === 'admin';
      // if (!isAdmin) {
      //   throw new functions.https.HttpsError(
      //     'permission-denied',
      //     'User is not an admin',
      //   );
      // }

      // MOCK DATA - Replace with actual metrics collection
      const mockMetrics: StreamingMetrics = {
        totalRequests: Math.floor(Math.random() * 500) + 100,
        successRate: 94 + Math.random() * 5,
        averageLatency: 2500 + Math.random() * 1000,
        estimatedCost: 15.75 + Math.random() * 10,
        activeStreams: Math.floor(Math.random() * 20),
        errorCount: Math.floor(Math.random() * 10),
        lastUpdated: new Date().toISOString(),
        backendStatus: 'online',
        backendRegion: 'us-east1',
        backendUrl: 'wss://presto-microia-stream-151421230024.us-east1.run.app/stream',
        trends: generateMockTrends(),
      };

      return mockMetrics;

    } catch (error) {
      console.error('Error fetching streaming metrics:', error);
      
      // Return default metrics if error
      const defaultMetrics: StreamingMetrics = {
        totalRequests: 0,
        successRate: 0,
        averageLatency: 0,
        estimatedCost: 0,
        activeStreams: 0,
        errorCount: 0,
        lastUpdated: new Date().toISOString(),
        backendStatus: 'offline',
        backendRegion: 'us-east1',
        backendUrl: 'wss://presto-microia-stream-151421230024.us-east1.run.app/stream',
        trends: [],
      };

      return defaultMetrics;
    }
  });

/**
 * IMPLEMENTATION GUIDE
 * 
 * To collect real metrics:
 * 
 * 1. Create a Firestore collection: "streamingEvents"
 *    - Document per request with: timestamp, latency, status, error
 *    - TTL: 30 days (via Firestore TTL policy)
 * 
 * 2. Backend (app.py) should write to Firestore after each request:
 *    ```python
 *    db.collection('streamingEvents').add({
 *        'timestamp': datetime.now(),
 *        'latency': response_time,
 *        'status': 'success' | 'error',
 *        'error_message': str(error) if error else None,
 *        'userId': user_id,
 *        'region': 'us-east1',
 *    })
 *    ```
 * 
 * 3. Query Firestore in this function:
 *    ```typescript
 *    const today = new Date();
 *    today.setHours(0, 0, 0, 0);
 *    
 *    const events = await admin.firestore()
 *      .collection('streamingEvents')
 *      .where('timestamp', '>=', today)
 *      .get();
 *    
 *    const successCount = events.docs.filter(
 *      d => d.data().status === 'success'
 *    ).length;
 *    
 *    const totalLatency = events.docs.reduce(
 *      (sum, d) => sum + d.data().latency, 0
 *    );
 *    ```
 * 
 * 4. For cost estimation:
 *    - Cloud Run: 0.00002 USD per request
 *    - Speech-to-Text: 0.020 USD per 15 seconds
 *    - Generative AI: 0.075 USD per 1M input tokens
 *    
 * 5. For active streams:
 *    - Backend can publish to Firestore Realtime Database
 *    - Or expose /metrics endpoint to count active connections
 * 
 * 6. For trends (24h):
 *    - Query events for each hour
 *    - Group by timestamp_hour
 *    - Calculate avg latency per hour
 */

function generateMockTrends(): StreamingMetrics['trends'] {
  const trends = [];
  const now = new Date();

  for (let i = 23; i >= 0; i--) {
    const time = new Date(now);
    time.setHours(time.getHours() - i);

    trends.push({
      timestamp: time.toISOString(),
      requestCount: Math.floor(Math.random() * 50) + 10,
      averageLatency: 2500 + Math.random() * 1500,
    });
  }

  return trends;
}
