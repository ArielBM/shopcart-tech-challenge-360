export function required(name: string): string {
  const value = process.env[name];

  if (!value?.trim()) {
    throw new Error(`Variable de entorno requerida: ${name}`);
  }

  return value;
}