import { publicProcedure, router } from "../_core/trpc";
import { getDb } from "../db";
import { otpAuditLogs } from "../../drizzle/schema";
import { desc } from "drizzle-orm";

export const auditRouter = router({
  getLogs: publicProcedure.query(async () => {
    const db = await getDb();
    if (!db) return [];
    return await db.select().from(otpAuditLogs).orderBy(desc(otpAuditLogs.createdAt)).limit(100);
  }),
});
