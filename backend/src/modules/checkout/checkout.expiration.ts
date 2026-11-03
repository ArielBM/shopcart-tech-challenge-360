import { expireCheckoutReservations } from "./checkout.repository";

const EXPIRATION_INTERVAL_MS = 60_000;
const BATCH_SIZE = 50;

export function startCheckoutExpiration(): () => void {
  let stopped = false;
  let timeout: NodeJS.Timeout | undefined;

  async function execute(): Promise<void> {
    try {
      const expired = await expireCheckoutReservations(BATCH_SIZE);

      if (expired > 0) {
        console.log(`Checkouts expirados: ${String(expired)}`);
      }
    } catch {
      console.error("Error al procesar las reservas vencidas.");
    } finally {
      if (!stopped) {
        timeout = setTimeout(() => void execute(), EXPIRATION_INTERVAL_MS);
      }
    }
  }

  void execute();

  return () => {
    stopped = true;

    if (timeout) {
      clearTimeout(timeout);
    }
  };
}
