from locust import HttpUser, task, between
import os, random, string

BASE_URL = os.getenv("TARGET_BASE_URL", "https://traffic.nextcloudlab.com")

def rand_qs(n=8):
    return "".join(random.choices(string.ascii_letters + string.digits, k=n))

class WebUser(HttpUser):
    wait_time = between(0.05, 0.2)

    # 캐시 HIT (CloudFront 정적 리소스)
    @task(3)
    def cache_hit(self):
        self.client.get(f"{BASE_URL}/static/app.js", name="CF_CACHE_HIT_static")

    # 캐시 MISS (no-cache 헤더 + 랜덤 QS)
    @task(1)
    def cache_miss(self):
        self.client.get(
            f"{BASE_URL}/static/app.js?nocache={rand_qs()}",
            headers={"Cache-Control": "no-cache"},
            name="CF_CACHE_MISS_static"
        )

    # 동적 API (ALB → ASG 경로)
    @task(5)
    def dynamic_status(self):
        self.client.get(f"{BASE_URL}/api/v1/status", name="API_dynamic_status")

    # 세션 캐시 검증(선택 경로)
    @task(2)
    def session_profile(self):
        self.client.get(f"{BASE_URL}/api/v1/profile", name="API_session_profile")

# 실행 예:
# locust -f locustfile.py --headless -u 500 -r 50 -t 15m
# TARGET_BASE_URL=https://traffic.nextcloudlab.com locust -f locustfile.py --headless -u 500 -r 50 -t 15m
