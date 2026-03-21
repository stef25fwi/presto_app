export function mapProviderStatusToInternal(type: string): string {
  switch (type) {
    case "sent":
      return "sent";
    case "delivered":
      return "delivered";
    case "deferred":
      return "deferred";
    case "bounced":
      return "bounced";
    case "complained":
      return "complained";
    case "opened":
      return "opened";
    case "clicked":
      return "clicked";
    case "unsubscribed":
      return "unsubscribed";
    case "dropped":
      return "dropped";
    default:
      return "unknown";
  }
}
