# Deploy VayuNetra API (e.g. Lightsail)

## Nginx: API must return JSON

**Problem:** Mobile app gets HTML instead of JSON for `POST /api/reports`.

**Cause:** The request is not reaching FastAPI. Something in front of it (Nginx, load balancer, or wrong server block) is serving an HTML error page (e.g. 502, 413, or default site).

**Fix:**

1. **Use the right server block**  
   In `nginx.vayunetra.conf`, `server_name` must match the host the app uses (e.g. `api.vayunetra.com`). If you use an IP, set `server_name YOUR_LIGHTSAIL_IP;` or add it.

2. **Proxy everything to the backend**  
   All requests to this server_name must go to FastAPI:
   ```nginx
   location / {
       proxy_pass http://127.0.0.1:8000;
       ...
   }
   ```
   No `root` or `try_files` that could serve static HTML for `/api/*`.

3. **Apply and reload Nginx on Lightsail:**
   ```bash
   sudo cp /home/ubuntu/VayuNetra/backend/deploy/nginx.vayunetra.conf /etc/nginx/sites-available/vayunetra-api
   sudo ln -sf /etc/nginx/sites-available/vayunetra-api /etc/nginx/sites-enabled/
   # Remove or disable any default site that might catch api.vayunetra.com
   sudo nginx -t && sudo systemctl reload nginx
   ```

4. **Verify from the server:**
   ```bash
   curl -X POST http://127.0.0.1:8000/api/reports -F "area=Test" -F "latitude=12.97" -F "longitude=77.59" -F "photo=@/path/to/small.jpg"
   ```
   You should get JSON. If you get JSON on 127.0.0.1 but HTML via https://api.vayunetra.com, the proxy/server_name is wrong.

5. **HTTPS (Lightsail LB / Let's Encrypt)**  
   If you use a load balancer or another layer for SSL, ensure it forwards to this Nginx (or directly to port 8000) and doesn’t serve its own HTML error pages for `/api/*`.

---

## Using `.env` on Lightsail

The systemd unit loads `EnvironmentFile=/home/ubuntu/VayuNetra/backend/.env`. Create that file on the server with production values; do not commit it. Then:

```bash
sudo systemctl restart vayunetra-api
```

---

## Manual deploy

```bash
cd /home/ubuntu/VayuNetra && git pull
cd backend && source venv/bin/activate && pip install -r requirements.txt
sudo systemctl restart vayunetra-api
```
