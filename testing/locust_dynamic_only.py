from locust import HttpUser, task, between
import os

# 한글: host를 클래스에 명시. 상대 경로로 요청.
class WebUser(HttpUser):
    wait_time = between(0.01, 0.05)
    host = os.getenv(
        "TARGET_BASE_URL",
        "http://traffic-alb-asg-alb-934945083.ap-northeast-2.elb.amazonaws.com"
    )

    @task(7)
    def dynamic_status(self):
        self.client.get("/api/v1/status", name="API_dynamic_status")

    @task(3)
    def session_profile(self):
        self.client.get("/api/v1/profile", name="API_session_profile")
