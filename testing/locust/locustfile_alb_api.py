from locust import HttpUser, task, between
import random, string

def r(n=8):
    return "".join(random.choices(string.ascii_letters + string.digits, k=n))

class WebUser(HttpUser):
    wait_time = between(0.01, 0.05)

    @task(7)
    def dynamic_status(self):
        self.client.get(f"/api/v1/status?rnd={r()}", name="API_dynamic_status")

    @task(3)
    def session_profile(self):
        self.client.get(f"/api/v1/profile?rnd={r()}", name="API_session_profile")
