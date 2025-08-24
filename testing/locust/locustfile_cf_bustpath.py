import os, random, string
from locust import HttpUser, task, between

def r(n=12):
    return "".join(random.choices(string.ascii_letters + string.digits, k=n))

CF_DOMAIN = os.getenv("CF_DOMAIN")

class WebUser(HttpUser):
    wait_time = between(0.03, 0.12)

    def on_start(self):
        assert CF_DOMAIN, "CF_DOMAIN is required"
        self.client.base_url = f"https://{CF_DOMAIN}"
        self.client.headers.update({
            "Cache-Control": "no-cache",
            "Pragma": "no-cache",
            "User-Agent": "Locust-CF/uncache-1.0"
        })

    @task(10)
    def hit_random_path(self):
        # always MISS in CloudFront → forwarded to ALB
        self.client.get(f"/__probe/{r()}", name="/__probe/*")
