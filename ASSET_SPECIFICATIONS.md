# Panduan Spesifikasi Teknis Aset 3D — Nusantara: Takhta Delapan Petak

Dokumen ini menjadi standar wajib produksi aset 3D (Blender ke Godot 4) agar seluruh model dapat langsung diintegrasikan ke dalam *game engine* secara presisi sesuai koordinat grid papan (`tile_size = 1.0`, permukaan papan `Y = 0.0`).

---

## 1. Aturan Wajib Global (Blender $\rightarrow$ Godot 4)

Setiap aset yang diekspor wajib memenuhi lima standar teknis berikut:

1. **Format File:** `.glb` (glTF Binary) dengan tekstur ter-embed (*Pack Resources* aktif saat ekspor).
2. **Skala Unit:** **1 Blender Unit = 1 Meter = 1 Godot Unit**. Wajib menekan `Ctrl + A` $\rightarrow$ **Apply Scale & Rotation** sebelum ekspor sehingga nilai *Scale* di Blender bernilai tepat `(1.0, 1.0, 1.0)`.
3. **Arah Hadap Depan (*Forward Axis*):** Objek menghadap ke **sumbu `-Y` di Blender** (otomatis dikonversi menjadi **`-Z` di Godot**).
4. **Titik Tumpu (*Origin / Pivot Point*):**
   * **Bidak Catur & Properti Lingkungan (Obor, Candi, Pohon):** *Origin* wajib berada tepat di **tengah alas paling bawah objek (`Z = 0` di Blender / `Y = 0.0` di Godot)** agar alasnya menempel rata di atas permukaan papan atau tanah.
   * **Ubin Petak Papan (*Board Tile*):** *Origin* wajib berada di **tengah permukaan paling atas ubin (`Y = 0.0` di Godot)** sehingga ketebalan ubin menjorok ke bawah (`Y = 0.0` hingga `Y = -0.2`).
5. **Batas Poligon (*Polycount Budget*):**
   * **Bidak Catur:** Maksimal **8.000 – 15.000 triangles** per bidak (menjaga performa 60 FPS untuk 32 bidak sekaligus).
   * **Aset Lingkungan (Candi Bentar, Bingkai Papan):** Maksimal **20.000 triangles**.

---

## 2. Daftar & Dimensi Spesifik Aset

### A. Papan & Lingkungan Utama (`assets/models/environment/`)

| Nama File | Deskripsi Visual | Dimensi Wajib ($P \times L \times T$) | Catatan Teknis |
| :--- | :--- | :--- | :--- |
| `tile_light.glb` | Ubin batu andesit terang / gading berukir motif klasik | `1.0m` $\times$ `1.0m` $\times$ `0.2m` | Permukaan atas harus rata (`Y = 0.0`) agar bingkai *highlight* emas tidak tenggelam. |
| `tile_dark.glb` | Ubin batu gelap / kayu jati tua berukir | `1.0m` $\times$ `1.0m` $\times$ `0.2m` | Dimensi identik dengan `tile_light.glb`, dibedakan pada material/tekstur. |
| `board_frame.glb` | Bingkai kayu ukir Jepara/Majapahit keliling papan | Lubang dalam: `8.0m` $\times$ `8.0m`<br>Bibir luar: `~9.2m` $\times$ `9.2m` | Bagian tengah wajib berlubang `8.0m x 8.0m` tepat di titik pusat `(0, 0, 0)`. |
| `torch_pillar.glb` | Tiang obor batu/kayu dengan mangkuk api di puncak | Diameter alas: `0.5m`<br>Tinggi total: **`2.2m`** | Puncak mangkuk api berada tepat di ketinggian **`2.2m`** agar sejajar dengan node `TorchLight_1..4` (`Y = 2.2`). |
| `candi_bentar.glb` | Gapura pecah khas Nusantara sebagai gerbang latar | Lebar total: `~6.0m`<br>Tinggi: `~5.5m` – `7.0m` | Ditempatkan di sisi luar papan (`Z = -9.0m`) sebagai titik fokus latar belakang. |
| `courtyard_floor.glb` | Lantai pelataran batu candi luas & properti sudut (sesajen) | Luas: `24.0m` $\times$ `24.0m` | Ditempatkan pada ketinggian `Y = -0.2m` (tepat di bawah dasar papan catur). |

---

### B. Bidak Catur Faksi Nusantara (`assets/models/pieces/`)

Setiap bidak wajib memiliki **umpak/alas bundar berukir (*pedestal base*)** berdiameter **`0.72m` – `0.78m`** agar proporsional di dalam petak `1.0m` dan pas di dalam bingkai seleksi emas `0.94m`.

| Nama File | Peran Catur | Konsep Visual Nusantara | Diameter Alas | Tinggi Total |
| :--- | :--- | :--- | :--- | :--- |
| `piece_pawn.glb` | Pion (*Pawn*) | Prajurit tombak & perisai kayu berjarit batik | `0.70m` | **`0.85m` – `0.95m`** |
| `piece_rook.glb` | Benteng (*Rook*) | Menara Candi / Candi Perwara kokoh | `0.75m` | **`1.10m` – `1.20m`** |
| `piece_knight.glb` | Kuda (*Knight*) | Ksatria berkuda / patung kuda perang berzirah | `0.75m` | **`1.15m` – `1.25m`** |
| `piece_bishop.glb` | Gajah / Menteri (*Bishop*) | Gajah perang berpelana kerajaan / Resi | `0.76m` | **`1.25m` – `1.35m`** |
| `piece_queen.glb` | Patih / Permaisuri (*Queen*) | Mahapatih / Ratu bermahkota & jubah kerajaan | `0.78m` | **`1.40m` – `1.50m`** |
| `piece_king.glb` | Raja (*King*) | Maharaja Nusantara dengan mahkota agung & keris | `0.80m` | **`1.55m` – `1.65m`** |

---

## 3. Strategi Material Dua Faksi

Tim 3D Artist cukup membuat **6 model dasar** bidak di atas dengan *UV Map* yang rapi. Kedua kubu dibedakan menggunakan dua varian material (ekspor dua varian atau gunakan *material override* di Godot):

* **Faksi Emas (`GOLD`):** Dominan perunggu hangat, aksen emas pada mahkota/perisai, serta kain merah marun atau cokelat soga.
* **Faksi Obsidian (`OBSIDIAN`):** Dominan batu candi andesit gelap, besi hitam tempa, serta aksen perak tua.

---

## 4. Alur Kerja Git & Penempatan File

1. Pastikan berada di *branch* `main` terbaru sebelum memulai pekerjaan:
   ```powershell
   git checkout main
   git pull origin main
   ```

2. Buat *branch* khusus untuk pengerjaan aset 3D:
   ```powershell
   git checkout -b feat/3d-assets-pieces
   ```

3. Simpan seluruh file ekspor sesuai struktur folder berikut (file `.glb` otomatis ditangani oleh **Git LFS**):
   - **Model Bidak:** `assets/models/pieces/`
   - **Model Lingkungan & Papan:** `assets/models/environment/`
   - **Tekstur Eksternal (opsional):** `assets/textures/`

4. Lakukan *commit* dan *push* dengan format standar proyek:
   ```powershell
   git add .
   git commit -m "feat(assets): add 3D Nusantara chess piece models"
   git push -u origin feat/3d-assets-pieces
   ```

---

### Cara Memasukkan ke GitHub

Setelah file `ASSET_SPECIFICATIONS.md` dibuat di dalam folder `nusantara-chess`, naikkan ke GitHub menggunakan *branch* dokumentasi:

```powershell
git checkout -b docs/asset-specifications
git add ASSET_SPECIFICATIONS.md
git commit -m "docs(assets): add 3D modeling specifications and Blender-to-Godot guidelines"
git push -u origin docs/asset-specifications
```