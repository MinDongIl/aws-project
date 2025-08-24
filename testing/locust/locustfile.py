from locust import HttpUser, task, between, LoadTestShape
import os, random, string, time, json

def env(name, default): 
    v = os.getenv(name)
    return v if v is not None and v != "" else default

HOST = env("TARGET_BASE_URL", "https://traffic.nextcloudlab.com")

PATH_DEFAULT  = env("PATH_DEFAULT", "/")
PATH_CACHEOBJ = env("PATH_CACHEOBJ", "/index.html")
PATH_STATUS   = env("PATH_STATUS", "/api/v1/status")
PATH_PROFILE  = env("PATH_PROFILE", "/api/v1/profile")
WRITE_PATH    = env("WRITE_PATH", "")
WRITE_RATIO   = float(env("WRITE_RATIO", "0.0"))

WEIGHT_HOME    = int(env("WEIGHT_HOME", "6"))
WEIGHT_HIT     = int(env("WEIGHT_HIT", "2"))
WEIGHT_MISS    = int(env("WEIGHT_MISS", "1"))
WEIGHT_STATUS  = int(env("WEIGHT_STATUS", "4"))
WEIGHT_PROFILE = int(env("WEIGHT_PROFILE", "2"))
WEIGHT_WRITE   = int(env("WEIGHT_WRITE", "3"))

WAIT_MIN = float(env("WAIT_MIN", "0.02"))
WAIT_MAX = float(env("WAIT_MAX", "0.20"))

SPIKE_LOW   = int(env("SPIKE_LOW", "300"))
SPIKE_HIGH  = int(env("SPIKE_HIGH", "1200"))
T_RAMP      = int(env("T_RAMP", "120"))
T_SPIKE     = int(env("T_SPIKE", "240"))
T_PLATEAU   = int(env("T_PLATEAU", "360"))
T_TOTAL     = int(env("T_TOTAL", "1200"))

def rand_qs(n=8): 
    return "".join(random.choices(string.ascii_letters + string.digits, k=n))

def rid(prefix): 
    return f"{prefix}-{int(time.time()*1000)}"

class WebUser(HttpUser):
    host = HOST
    wait_time = between(WAIT_MIN, WAIT_MAX)

    @task(WEIGHT_HOME)
    def home(self):
        self.client.get(PATH_DEFAULT, name="HOME")

    @task(WEIGHT_HIT)
    def cache_hit(self):
        self.client.get(PATH_CACHEOBJ, name="CF_CACHE_HIT_static")

    @task(WEIGHT_MISS)
    def cache_miss(self):
        self.client.get(f"{PATH_CACHEOBJ}?nocache={rand_qs()}",
                        headers={"Cache-Control": "no-cache"},
                        name="CF_CACHE_MISS_static")

    @task(WEIGHT_STATUS)
    def dynamic_status(self):
        self.client.get(PATH_STATUS, name="API_dynamic_status")

    @task(WEIGHT_PROFILE)
    def session_profile(self):
        self.client.get(PATH_PROFILE, name="API_session_profile")

    @task(WEIGHT_WRITE)
    def write_event(self):
        if not WRITE_PATH:
            return
        if random.random() > WRITE_RATIO:
            return
        body = {"sessionId": rid("s"), "userId": rid("u"), "ts": int(time.time())}
        self.client.post(WRITE_PATH, data=json.dumps(body),
                         headers={"Content-Type": "application/json"},
                         name="API_write_event")

class SpikeShape(LoadTestShape):
    def tick(self):
        t = self.get_run_time()
        if t > T_TOTAL:
            return None
        if t <= T_RAMP:
            u = int(SPIKE_LOW * (t / max(1, T_RAMP)))
            r = max(10, u // 10)
        elif t <= T_RAMP + T_SPIKE:
            u = SPIKE_HIGH
            r = max(50, u // 12)
        elif t <= T_RAMP + T_SPIKE + T_PLATEAU:
            u = SPIKE_LOW
            r = max(20, u // 10)
        else:
            done = t - (T_RAMP + T_SPIKE + T_PLATEAU)
            rem = max(1, T_TOTAL - (T_RAMP + T_SPIKE + T_PLATEAU))
            u = max(1, int(SPIKE_LOW * (1 - done / rem)))
            r = max(10, u // 10)
        return (u, r)
