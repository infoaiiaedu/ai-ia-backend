# bog_client.py

import base64
import httpx
from django.conf import settings
import time

class BOGClient:
    def __init__(self):
        self.client_id = settings.BOG_CLIENT_ID
        self.client_secret = settings.BOG_CLIENT_SECRET
        self.token_url = settings.BOG_OAUTH_TOKEN_URL
        self._access_token = None
        self._expires_at = 0

    async def get_access_token(self):
        now = time.time()
        if self._access_token and now < self._expires_at - 60:  # refresh a bit early
            return self._access_token

        auth = base64.b64encode(f"{self.client_id}:{self.client_secret}".encode()).decode()
        headers = {
            "Authorization": f"Basic {auth}",
            "Content-Type": "application/x-www-form-urlencoded",
        }
        data = {"grant_type": "client_credentials"}
        async with httpx.AsyncClient() as client:
            resp = await client.post(self.token_url, data=data, headers=headers)
            resp.raise_for_status()
            j = resp.json()
            access = j["access_token"]
            expires = j.get("expires_in", 0)
            self._access_token = access
            self._expires_at = now + expires
            return access
