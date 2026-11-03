import type { Request, Response } from "express";

import { auditQuerySchema } from "./audit.schemas";
import { getAuditRecordsService } from "./audit.service";

export async function listAuditRecords(
  req: Request,
  res: Response,
): Promise<void> {
  const filters = auditQuerySchema.parse(req.query);

  const result = await getAuditRecordsService(filters);

  res.status(200).json(result);
}
