import os, time, random, string
import boto3
from botocore.config import Config
from locust import User, task, between

def rnd(n=12):
    return "".join(random.choices(string.ascii_letters + string.digits, k=n))

TABLE_NAME = os.getenv("TABLE_NAME", "traffic-session")
AWS_REGION = os.getenv("AWS_REGION", "ap-northeast-2")
READ_RATIO = float(os.getenv("READ_RATIO", "0.6"))
PK_NAME = os.getenv("PK_NAME", "pk")
SK_NAME = os.getenv("SK_NAME", "sk")
PARTITION_CARDINALITY = int(os.getenv("PARTITION_CARDINALITY", "50000"))
TTL_ATTR = os.getenv("TTL_ATTR", "ttl")
TTL_SEC = int(os.getenv("TTL_SEC", "3600"))
CONSISTENT_READ = os.getenv("CONSISTENT_READ", "false").lower() == "true"

class DdbUser(User):
    wait_time = between(0.005, 0.02)

    def on_start(self):
        self.ddb = boto3.client(
            "dynamodb",
            region_name=AWS_REGION,
            config=Config(retries={"max_attempts": 5, "mode": "standard"})
        )

    def _fire(self, name, start, ok=True, exc=None, bytes_=0):
        rt = (time.perf_counter() - start) * 1000.0
        self.environment.events.request.fire(
            request_type="dynamodb",
            name=name,
            response_time=rt,
            response_length=bytes_,
            exception=None if ok else exc,
        )

    def _key(self):
        pk = f"u#{random.randint(1, PARTITION_CARDINALITY)}"
        key = {PK_NAME: {"S": pk}}
        if SK_NAME:
            key[SK_NAME] = {"S": "p#session"}
        return key

    @task
    def read_item(self):
        if random.random() > READ_RATIO:
            return
        start = time.perf_counter()
        try:
            self.ddb.get_item(
                TableName=TABLE_NAME,
                Key=self._key(),
                ConsistentRead=CONSISTENT_READ
            )
            self._fire("GetItem", start, ok=True)
        except Exception as e:
            self._fire("GetItem", start, ok=False, exc=e)

    @task
    def write_item(self):
        if random.random() < READ_RATIO:
            return
        start = time.perf_counter()
        try:
            item = self._key()
            item.update({
                "ts": {"N": str(int(time.time() * 1000))},
                "rnd": {"S": rnd()},
                TTL_ATTR: {"N": str(int(time.time()) + TTL_SEC)}
            })
            self.ddb.put_item(TableName=TABLE_NAME, Item=item)
            self._fire("PutItem", start, ok=True)
        except Exception as e:
            self._fire("PutItem", start, ok=False, exc=e)
