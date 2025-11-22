# Deployment Guide untuk Dokploy

Panduan ini menjelaskan cara deploy aplikasi Project Management ke VPS menggunakan Dokploy.

## Prerequisites

1. VPS dengan Dokploy terinstall
2. Domain yang sudah diarahkan ke IP VPS
3. Database MySQL/MariaDB (bisa menggunakan database service di Dokploy atau external)
4. Akses SSH ke VPS

## Langkah-langkah Deployment

### 1. Persiapan Repository

Pastikan semua perubahan sudah di-commit dan push ke repository:

```bash
git add .
git commit -m "Prepare for deployment"
git push origin main
```

### 2. Setup di Dokploy

1. **Login ke Dokploy Panel**
   - Buka panel Dokploy di VPS Anda
   - Login dengan kredensial admin

2. **Buat Project Baru**
   - Klik "New Project" atau "Add Project"
   - Pilih "Docker" sebagai deployment type
   - Isi informasi project:
     - **Name**: project-management (atau nama yang diinginkan)
     - **Repository**: URL repository Git Anda
     - **Branch**: main (atau branch yang digunakan)
     - **Port**: 80 (atau port yang diinginkan)

3. **Konfigurasi Environment Variables**
   - Di halaman project, buka tab "Environment Variables"
   - Tambahkan semua variabel dari `.env.example`:
     ```
     APP_NAME=Project Management
     APP_ENV=production
     APP_KEY=base64:... (generate dengan: php artisan key:generate)
     APP_DEBUG=false
     APP_URL=https://yourdomain.com
     
     DB_CONNECTION=mysql
     DB_HOST=your-db-host
     DB_PORT=3306
     DB_DATABASE=project_management
     DB_USERNAME=your-db-user
     DB_PASSWORD=your-db-password
     
     SESSION_DRIVER=database
     QUEUE_CONNECTION=database
     
     MAIL_MAILER=smtp
     MAIL_HOST=smtp.gmail.com
     MAIL_PORT=587
     MAIL_USERNAME=your-email@gmail.com
     MAIL_PASSWORD=your-app-password
     MAIL_ENCRYPTION=tls
     MAIL_FROM_ADDRESS=your-email@gmail.com
     MAIL_FROM_NAME="Project Management"
     
     GOOGLE_CLIENT_ID=your-google-client-id
     GOOGLE_CLIENT_SECRET=your-google-client-secret
     ```

4. **Konfigurasi Build Settings**
   - **Dockerfile Path**: `Dockerfile` (default)
   - **Build Context**: `.` (root directory)
   - **Docker Compose**: Tidak digunakan (gunakan Dockerfile langsung)

5. **Konfigurasi Nginx/Web Server**
   - Dokploy biasanya sudah menyediakan reverse proxy
   - Pastikan domain diarahkan ke container
   - Port mapping: 80:9000 (atau sesuai konfigurasi)

### 3. Setup Database

Jika menggunakan database eksternal:

1. Buat database dan user di MySQL/MariaDB
2. Update environment variables `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
3. Pastikan VPS bisa mengakses database (firewall rules)

Jika menggunakan database service di Dokploy:

1. Buat database service di Dokploy
2. Gunakan service name sebagai `DB_HOST` (misal: `db` atau `mysql`)
3. Update environment variables sesuai dengan service

### 4. Entrypoint Script

Aplikasi sudah dilengkapi dengan `docker-entrypoint.sh` yang akan otomatis:
- Menjalankan migrations
- Cache configuration, routes, dan views
- Membuat storage link
- Set permissions yang benar

Script ini akan otomatis dijalankan saat container start. Jika Anda perlu menjalankan seeder untuk pertama kali, bisa dilakukan via Dokploy console atau SSH:

```bash
docker exec -it <container-name> php artisan db:seed --class=RoleSeeder --force
```

### 5. Setup Queue Worker

Untuk production, queue worker harus berjalan. Ada beberapa opsi:

#### Opsi 1: Menggunakan Supervisor (Recommended)

1. SSH ke VPS
2. Install supervisor:
   ```bash
   sudo apt-get update
   sudo apt-get install supervisor -y
   ```

3. Buat file konfigurasi `/etc/supervisor/conf.d/laravel-worker.conf`:
   ```ini
   [program:laravel-worker]
   process_name=%(program_name)s_%(process_num)02d
   command=php /path/to/your/project/artisan queue:work --sleep=3 --tries=3 --max-time=3600
   autostart=true
   autorestart=true
   stopasgroup=true
   killasgroup=true
   user=www-data
   numprocs=2
   redirect_stderr=true
   stdout_logfile=/path/to/your/project/storage/logs/worker.log
   stopwaitsecs=3600
   ```

4. Update supervisor:
   ```bash
   sudo supervisorctl reread
   sudo supervisorctl update
   sudo supervisorctl start laravel-worker:*
   ```

#### Opsi 2: Menggunakan Docker Container Terpisah

Tambahkan service queue worker di docker-compose atau buat container terpisah di Dokploy.

### 6. Setup Storage Link

Pastikan storage link sudah dibuat. Bisa dilakukan melalui:

1. **Via Dokploy Console/SSH**:
   ```bash
   docker exec -it <container-name> php artisan storage:link
   ```

2. **Via Deployment Script** (jika ada):
   Script di atas sudah termasuk `php artisan storage:link`

### 7. Setup SSL/HTTPS

1. Di Dokploy, aktifkan SSL untuk domain
2. Dokploy biasanya menggunakan Let's Encrypt untuk SSL otomatis
3. Pastikan `APP_URL` di environment variables menggunakan `https://`

### 8. Deploy

1. Di panel Dokploy, klik "Deploy" atau "Redeploy"
2. Tunggu proses build dan deployment selesai
3. Cek logs jika ada error

### 9. Post-Deployment

Setelah deployment berhasil:

1. **Cek aplikasi**:
   - Buka `https://yourdomain.com/admin`
   - Login dengan akun superadmin (dari seeder)

2. **Cek queue worker**:
   ```bash
   sudo supervisorctl status laravel-worker:*
   ```

3. **Cek logs**:
   ```bash
   docker logs <container-name>
   ```

4. **Test email notifications** (jika sudah dikonfigurasi)

## Troubleshooting

### Error: Vite manifest not found
- Pastikan `npm run build` sudah dijalankan di Dockerfile
- Cek apakah folder `public/build` ada dan berisi `manifest.json`

### Error: Database connection failed
- Cek environment variables `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`
- Pastikan database service bisa diakses dari container
- Cek firewall rules

### Error: Permission denied
- Pastikan permissions untuk storage dan bootstrap/cache sudah benar
- Jalankan: `chmod -R 755 storage bootstrap/cache`

### Queue tidak berjalan
- Cek apakah supervisor sudah terinstall dan running
- Cek logs: `tail -f storage/logs/worker.log`
- Restart supervisor: `sudo supervisorctl restart laravel-worker:*`

### Assets tidak loading
- Pastikan `npm run build` sudah dijalankan
- Cek apakah `public/build` folder ada
- Clear cache: `php artisan cache:clear && php artisan config:clear`

## Maintenance

### Update Application

1. Push perubahan ke repository
2. Di Dokploy, klik "Redeploy"
3. Tunggu proses selesai

### Backup Database

Lakukan backup database secara berkala:

```bash
mysqldump -u username -p database_name > backup_$(date +%Y%m%d).sql
```

### Monitor Logs

- **Application logs**: `storage/logs/laravel.log`
- **Queue worker logs**: `storage/logs/worker.log` (jika menggunakan supervisor)
- **Docker logs**: `docker logs <container-name>`

## Environment Variables Reference

Lihat file `.env.example` untuk daftar lengkap environment variables yang diperlukan.

## Support

Jika mengalami masalah, cek:
1. Logs aplikasi dan container
2. Dokumentasi Dokploy
3. Laravel documentation
4. GitHub issues repository

