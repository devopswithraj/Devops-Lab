

```bash
sudo dnf install -y postgresql16
psql --version

psql postgresql://postgres:Admin1234@app-2tier.cvik8accw2tk.ap-south-1.rds.amazonaws.com:5432/mydb



pg_restore --dbname="postgresql://postgres:Admin1234@app-2tier.cvik8accw2tk.ap-south-1.rds.amazonaws.com:5432/mydb" backup.dump
```