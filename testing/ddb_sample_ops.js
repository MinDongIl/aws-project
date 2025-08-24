import { PutCommand, GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { doc, tableName } from "../src/ddb_client.js";
import { buildSessionPk, buildTsSk, nowIso, ttlFromNow } from "../src/ddb_keys.js";

async function main() {
  const userId = process.env.USER_ID || `u-${Date.now()}`;
  const sessionId = process.env.SESSION_ID || `s-${Date.now()}`;
  const createdAt = nowIso();
  const ttl = ttlFromNow(3600);

  const pk = buildSessionPk(sessionId);
  const sk = buildTsSk(createdAt);

  await doc.send(new PutCommand({ TableName: tableName, Item: { pk, sk, userId, createdAt, ttl, type: "SESSION_EVENT" } }));
  const got = await doc.send(new GetCommand({ TableName: tableName, Key: { pk, sk }, ConsistentRead: true }));
  const q = await doc.send(new QueryCommand({
    TableName: tableName,
    IndexName: "userId-createdAt-index",
    KeyConditionExpression: "userId = :u AND createdAt >= :c",
    ExpressionAttributeValues: { ":u": userId, ":c": createdAt },
    Limit: 1, ScanIndexForward: false
  }));

  console.log(JSON.stringify({ put: { pk, sk }, get: got.Item, gsiFirst: q.Items?.[0] }, null, 2));
}
main().catch(e => { console.error(e); process.exit(1); });
