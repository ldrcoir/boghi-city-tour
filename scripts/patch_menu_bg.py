#!/usr/bin/env python3
# پچ ناحیه متن جعلی داخل آسمان گرادیانی menu_bg_raw.png
# روش: درون‌یابی افقی از لبه‌های چپ/راست bbox (آسمان صاف است)
from PIL import Image
import numpy as np

SRC = '/home/z/my-project/scripts/car_gen/menu_bg_raw.png'
im = Image.open(SRC).convert('RGB')
a = np.asarray(im).astype(np.float32)
h, w, _ = a.shape

# bbox ناحیه متن (با حاشیه)
x0, y0, x1, y1 = 320, 20, 950, 320
# پچ پله‌ای با بلور افقی: برای هر ردیف، بین رنگ لبه چپ و راست درون‌یابی خطی + نویز نرم
for y in range(y0, y1):
    left = a[y, x0 - 8:x0 - 1].mean(axis=0)
    right = a[y, x1 + 1:x1 + 8].mean(axis=0)
    n = x1 - x0
    t = np.linspace(0.0, 1.0, n)[:, None]
    row = left[None, :] * (1 - t) + right[None, :] * t
    a[y, x0:x1] = row

# کمی بلور عمودی روی ناحیه پچ‌شده تا با آسمان یکدست شود
from scipy.ndimage import gaussian_filter
patch = a[y0:y1, x0:x1]
a[y0:y1, x0:x1] = gaussian_filter(patch, sigma=(6, 9, 0))

out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
out.save(SRC.replace('_raw', '_raw_clean'))
print('saved', SRC.replace('_raw', '_raw_clean'))
