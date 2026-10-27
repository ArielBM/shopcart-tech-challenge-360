import { required } from './config.utils';

export const databaseConfig = {
  server: required('DB_SERVER'),
  port: Number(process.env.DB_PORT ?? 1433),
  database: required('DB_NAME'),
  user: required('DB_USER'),
  password: required('DB_PASSWORD'),
  encrypt: process.env.DB_ENCRYPT !== 'false',
  trustServerCertificate:
    process.env.DB_TRUST_SERVER_CERTIFICATE === 'true',
};